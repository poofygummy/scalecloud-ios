What iloader is
iloader is a Tauri desktop app (Rust backend + React/TypeScript frontend) for sideloading IPA files onto iOS devices. It has two modes:

Normal Mode vs. ScaleCloud (Minimal) Mode
How the mode is decided
App.tsx calls the Rust command is_scalecloud_mode() at startup
That command checks if the app was launched with the --scalecloud flag as a CLI arg
If yes → renders AppMinimal (ScaleCloud installer UI)
If no → renders AppNormal (full sideloading UI)

---

Complete ScaleCloud Install Flow — Every Function, In Order

PHASE 0 — iloader starts up

  App.tsx useEffect on mount
    calls invoke("is_scalecloud_mode")
    → is_scalecloud_mode() (lib.rs / main.rs, Tauri command)
        reads std::env::args(), looks for --scalecloud. Returns true if found.
    App.tsx: mode state becomes "scalecloud", React renders <MinimalApp /> (AppMinimal.tsx)


PHASE 1 — User logs in on the Mac

  AppMinimal.tsx renders:
    <AppleID isScaleCloudMode={true} /> + "Install ScaleCloud" button

  User types email + password and submits the form.

  AppleID.tsx form onSubmit
    sees isScaleCloudMode === true, calls:
    invoke("login_scalecloud", { email, password, anisetteServer })

  login_scalecloud() (account.rs, Tauri command)
    1. Ignores the anisetteServer argument entirely.
       Hard-codes "http://127.0.0.1:6970" (local Tailscale-routed anisette proxy).
    2. Calls internal login() with those credentials.

  login() (account.rs, internal async fn)
    1. Builds tfa_closure:
         if Apple requires 2FA, emits "2fa-required" to the frontend and blocks
         on an mpsc channel (120 s timeout).
         AppleID.tsx listens for "2fa-required" → opens TFA modal.
         On submit, frontend emits "2fa-recieved".
    2. AppleAccount::builder(email)
         .anisette_provider(RemoteV3AnisetteProvider … set_url("http://127.0.0.1:6970"))
         .login(password, tfa_closure)
         .await
       — isideload Apple authentication via local anisette proxy.
    3. DeveloperSession::from_account(&mut account).await
       — establishes Apple Developer portal session.
    4. Builds max_certs_callback:
         if at certificate limit, emits "max-certs-reached" to frontend with the
         cert list and blocks for "max-certs-response" (300 s timeout).
         Frontend shows cert selection modal.
    5. SideloaderBuilder::new(dev_session, email)
           .machine_name("iloader")
           .storage(create_sideloading_storage(app))
           .max_certs_behavior(MaxCertsBehavior::Prompt(max_certs_callback))
           .build()
       Returns Sideloader.

  Back in login_scalecloud():
    1. Stores Sideloader into SideloaderMutex.
    2. Builds ScalecloudCredentials { email, password }.
    3. ScalecloudSession::new(&credentials)  (scalecloud_session.rs)
           OsRng → 32-byte key + 12-byte nonce.
           Formats plaintext as "email\npassword".
           ChaCha20Poly1305::encrypt(nonce, plaintext).
           Returns ScalecloudSession { key, nonce, ciphertext }.
    4. Stores ScalecloudSession into ScalecloudSessionMutex.

  AppleID.tsx: toast resolves → invoke("logged_in_as") returns email →
  setLoggedInAs(email) is called.


PHASE 2 — Install operation kicks off automatically

  AppMinimal.tsx useEffect watching loggedInAs
    loggedInAs is now set → calls handleInstallScaleCloud()
    → invoke("install_scalecloud_operation")

  install_scalecloud_operation() (scalecloud.rs, Tauri command — main orchestrator)

  ── Step 0: Get UDID and device info ───────────────────────────────────────────

    1. Reads std::env::args(), finds --udid=<VALUE>. Fails hard if absent.

    2. get_device_version(&app_handle, &device_udid)
           Runs ideviceinfo sidecar: ideviceinfo -u <udid> -k ProductVersion
           Returns iOS version string e.g. "17.5.1". Falls back to "18.0" on any error.

    3. get_scalecloud_device(&device_udid, &device_version, &app_handle)

         get_usbmuxd()
           → UsbmuxdConnection::default()  — connects to local usbmuxd socket.

         usbmuxd.get_devices()  — lists all USB-connected devices.

         Finds device matching udid. Builds DeviceInfo { name, id, udid,
           connection_type: "USB", version }.

         pairing::pairing_file(&app_handle, &device_info, &mut usbmuxd, token)

           get_provider(&device_info)
             → get_provider_from_connection(&device_info, &mut usbmuxd)
                 usbmuxd.get_device(udid)
                 device.to_provider(UsbmuxdAddr, "iloader")
                 → UsbmuxdProvider

           generate_lockdown_plist(device, &provider, usbmuxd)
             usbmuxd.get_pair_record(&udid)   — fetches existing USB pairing record.
             LockdownClient::connect(provider) — opens lockdownd connection.
             lc.start_session(&pairing_file)  — authenticates session.
             lc.set_value("EnableWifiDebugging", true,
               "com.apple.mobile.wireless_lockdown")
             Serialises to plist::Value (lockdown plist).

           If iOS < 17.4:
             returns lockdown plist bytes directly (no RPPairing needed).

           If iOS ≥ 17.4:
             checks storage cache for key "rppairing_file_{udid}".
             If not cached → generate_rppairing_plist(&provider)
               → generate_rppairing(&provider, "iloader")
                   CoreDeviceProxy::connect(provider) — CDTunnel.
                   proxy.create_software_tunnel() → TCP stack.
                   RSD handshake → finds
                     com.apple.internal.dt.coredevice.untrusted.tunnelservice.
                   RemotePairingClient::new(...).connect(...)
                     generates RpPairingFile (may show "Trust" prompt on device).
                   Connects again to commit pairing to device keychain.
               Serialises to plist bytes. Stores in cache.
             Merges lockdown plist + rppairing plist via plist! macro.
             Returns combined Vec<u8>.

         Returns DeviceInfoWithPairing { info, pairing }.

    4. Stores DeviceInfoWithPairing into DeviceInfoMutex.

  ── Step 1: Find the IPA ───────────────────────────────────────────────────────

    std::env::current_exe().parent().join("ScaleCloud.ipa")
    Fails if the file does not exist.

  ── Step 2: Wait for Developer Mode ───────────────────────────────────────────

    app_handle.emit("scalecloud_status", "waiting_developer_mode")
    → AppMinimal.tsx renders the Developer Mode instruction card.

    wait_for_developer_mode(&app_handle, &device_udid)
      Loops with 1 s sleep between iterations:
        ideviceinfo -u <udid> -k DTXConnectionServices
        DTXConnectionServices is only present in lockdown output when
        Developer Mode is active on iOS 16+.
        Non-empty success output → returns Ok(()).

    app_handle.emit("scalecloud_status", "developer_mode_confirmed")

  ── Step 3: Sideload the IPA ──────────────────────────────────────────────────

    crate::sideload::sideload(device_state, sideloader_state, app_path)

      Reads DeviceInfoWithPairing from DeviceInfoMutex.
      get_provider(&device.info) → UsbmuxdProvider.
      SideloaderGuard::take(&sideloader_state) — takes Sideloader from mutex
        (returns it on drop).
      sideloader.install_app(&provider, app_path, false)
        isideload full pipeline: fetches / creates provisioning profile,
        signs IPA with Apple developer certificate,
        installs via InstallationProxyClient.

  ── Step 4: Mount Developer Disk Image (iOS < 17 only) ────────────────────────

    Parses major version number from iOS version string. If < 17:

      app_handle.path().app_cache_dir() — Tauri app cache directory.

      If DeveloperDiskImage.dmg or .signature not cached:
        reqwest::Client GET from:
          github.com/doronz88/DeveloperDiskImage/raw/main/
            DeveloperDiskImages/{version}/DeveloperDiskImage.dmg
          (and .signature)
        Writes both files to cache dir.

      ideviceimagemounter sidecar:
        ideviceimagemounter -u <udid> <dmg_path> <sig_path>
      Fails if exit status is non-zero.

  ── Step 5: Wait for Certificate Trust ────────────────────────────────────────

    app_handle.emit("scalecloud_status", "waiting_certificate_trust")
    → AppMinimal.tsx renders the Certificate Trust instruction card.

    wait_for_certificate_trust(&app_handle, &device_udid)
      Loops with 100 ms sleep between iterations:
        Spawns idevicedebug -u <udid> run com.scalecloud.app
          (throwaway launch just to probe for a trust error).
        Reads stderr for up to 2 seconds (CommandEvent::Stderr).
        If stderr contains "Could not" / "error" / "denied" → kill, retry.
        If no such error within 2 s → kill, return Ok(()).
        Rationale: idevicedebug fails with a permission / trust error until the
        user taps "Trust" on the device for this developer certificate.

    app_handle.emit("scalecloud_status", "certificate_trust_confirmed")

  ── Step 6: Credential injection via debug bridge ─────────────────────────────

    scalecloud_credential_injection(&device_udid, session_state, &app_handle)

    Sub-step 6a — Launch app, read public key:
      Configures idevicedebug sidecar:
        idevicedebug -u <udid> run com.scalecloud.app
      .spawn() → (rx: channel of CommandEvent, child: process handle)

      Reads CommandEvent::Stdout chunks, assembles into lines.
      Tracks `previous_line` (last non-empty line seen).
      When line == "SCALECLOUD_PUBKEY_READY":
        previous_line is the base64 public key. Break.
      BASE64_STANDARD.decode(key_line) → public_key_bytes
        (65-byte uncompressed P-256 point, 0x04 || X || Y).

    Sub-step 6b — Decrypt credentials from session, encrypt password for device:
      Locks ScalecloudSessionMutex.
      Takes and consumes the ScalecloudSession (one-shot; cannot be used again).
      ScalecloudSession::take()
        ChaCha20Poly1305::decrypt(nonce, ciphertext) → "email\npassword"
        splitn(2, '\n') → ScalecloudCredentials { email, password }.

      apple_ecies_encrypt(&public_key_bytes, password.as_bytes())
        EncodedPoint::from_bytes(public_key_bytes)   — parse 65-byte P-256 point.
        PublicKey::from_encoded_point(&device_point) — decode to P-256 key.
        EphemeralSecret::random(&mut rng)            — ephemeral P-256 keypair.
        ephemeral_secret.diffie_hellman(&device_pub) → raw shared secret (32 B).
        SHA-256(shared_secret || 0x00000001 || ephemeral_pub_65_bytes)
          → 32-byte key material.
        key_material[0..16]  = AES-128 key.
        key_material[16..32] = 16-byte IV (non-standard GCM nonce size).
        Aes128GcmU16::new_from_slice(aes_key).encrypt(nonce, password_bytes)
          → ciphertext + 16-byte GCM tag (appended).
        Returns ephemeral_pub_bytes(65) || ciphertext || tag(16).

      BASE64_STANDARD.encode(encrypted_blob) → encrypted_b64.

      Formats 5-line payload:
        "{encrypted_b64}\n{email}\n
         http://toth-adattar.tailf2b093.ts.net:6969\n
         toth-adattar.tailf2b093.ts.net\n
         SCALECLOUD_PAYLOAD_COMPLETE\n"

    Sub-step 6c — Send payload, wait for confirmation:
      child.write(payload_bytes)
        All 5 lines written to the process's stdin in one call.
      Resumes reading CommandEvent::Stdout, buffering output.
      Buffer contains "SCALECLOUD_CREDENTIALS_OK" → success = true, break.
      tokio::time::sleep(1 second).
      child.kill().
      Returns Err if success == false.

  install_scalecloud_operation() returns Ok(()).
  AppMinimal.tsx: invoke resolves → toast.success("credentials_prepared").


PHASE 3 — On the iOS device during Step 6

(Runs in parallel with iloader Step 6 above, on the device)

  Normal iOS app startup:
    SceneDelegate.scene(_:willConnectTo:options:)
    → startNextcloud()
    → launchMainInterface()
    → activateSceneForAccount()
    → presentSetupFlowIfNeeded(controller:)
        guard !UserDefaults.standard.setupCompleted  (first launch → false)
        DispatchQueue.main.asyncAfter(0.5 s):
          SetupCoordinator()  ← init()
            Creates CredentialInputViewController.
            UINavigationController(rootViewController: credentialVC)
            credentialVC.coordinator = self
            Returns immediately. No blocking work in init().

          setupCoordinator.start(from: controller)
            presentingViewController.present(navigationController, animated: true)

            DebuggerUtils.isDebuggerAttached()
              sysctl(CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid())
              kp_proc.p_flag & P_TRACED != 0
              idevicedebug attached via debugserver/ptrace → returns true.

            Dispatches to DispatchQueue.global(qos: .userInitiated):

            performDebugChannelHandoff()  ← runs on background thread, never main

              SecureEnclaveManager.generateKeyPair()
                SecKeyCreateRandomKey(kSecAttrTokenIDSecureEnclave,
                  kSecAttrKeyTypeECSECPrimeRandom, 256-bit, non-permanent)
                SecKeyCopyPublicKey(privateKey)
                SecKeyCopyExternalRepresentation(publicKey)
                  → 65-byte uncompressed P-256 point as Data
                Returns (publicKeyBytes: Data, privateKeyRef: SecKey)

              publicKeyBytes.base64EncodedString() → bare base64 string (no prefix)
              print(publicKeyBase64)         → stdout → iloader reads it
              print("SCALECLOUD_PUBKEY_READY") → sentinel
              fflush(stdout)

              while let line = readLine()    ← blocks background thread on stdin
                line 0 → encryptedPasswordBase64
                line 1 → appleID
                line 2 → anisetteURL
                line 3 → tailscaleHost  (logged, not stored)
                "SCALECLOUD_PAYLOAD_COMPLETE" → break

              guard all required fields present and base64 decodes OK

              SecureEnclaveManager.decrypt(encryptedData:using:)
                SecKeyIsAlgorithmSupported(privateKey, .decrypt,
                  .eciesEncryptionStandardVariableIVX963SHA256AESGCM)
                SecKeyCreateDecryptedData(privateKey,
                  .eciesEncryptionStandardVariableIVX963SHA256AESGCM,
                  encryptedData)
                  — Secure Enclave chip performs ECDH + X9.63 KDF +
                    AES-128-GCM (16-byte IV) internally.
                  — Private key never exposed outside the chip.
                Returns plaintext password as Data.

              String(data: passwordData, encoding: .utf8) → password

              Keychain.shared.appleIDEmailAddress = appleID
              Keychain.shared.appleIDPassword     = password

              UserDefaults.standard.menuAnisetteServersList (append anisetteURL)
              UserDefaults.standard.menuAnisetteURL = anisetteURL

              print("SCALECLOUD_CREDENTIALS_OK") → stdout → iloader receives it
              fflush(stdout)
              returns true

            DispatchQueue.main.async (success path):
              currentStep = .validation
              ValidationViewController()
              navigationController.setViewControllers([validationVC], animated: true)
              DispatchQueue.main.asyncAfter(0.3 s):
                validationVC.startValidation()

  Setup flow continues on device (independent of iloader from this point):
    validationSucceeded()
    → developerModeConfirmed()
    → certificateTrustConfirmed()
    → anisetteConfigured()
    → setupCompleted()
         UserDefaults.standard.setupCompleted = true
         UserDefaults.standard.lastSetupDate  = Date()
         NotificationCenter.post(.setupFlowCompleted)
         navigationController.dismiss()

  Meanwhile on the Mac: iloader has already killed idevicedebug 1 second after
  receiving SCALECLOUD_CREDENTIALS_OK and returned Ok(()) from
  install_scalecloud_operation().


---

Key Constants

  Anisette proxy used by iloader for login:    http://127.0.0.1:6970
  Anisette URL sent to app (payload line 3):   http://toth-adattar.tailf2b093.ts.net:6969
  Tailscale hostname sent to app (line 4):     toth-adattar.tailf2b093.ts.net
    (line 4 is for ScaleCloudApp's Nextcloud login flow, not stored by ScaleCloudRenew)
  App bundle ID:                               com.scalecloud.app


---

Backend Reference: ScalecloudSession (scalecloud_session.rs)

  A short-lived in-memory encrypted store for credentials.
  Lives between login_scalecloud() completing and scalecloud_credential_injection()
  consuming it.

  new(&credentials)
    OsRng → 32-byte key + 12-byte nonce.
    Formats plaintext: "email\npassword"
    ChaCha20Poly1305::encrypt(nonce, plaintext) → ciphertext.
    Stores { key, nonce, ciphertext }.

  take(self) → ScalecloudCredentials
    ChaCha20Poly1305::decrypt(nonce, ciphertext) → plaintext.
    splitn(2, '\n') → { email, password }.
    Consumes self — cannot be called twice.

  Purpose: keeps credentials out of plain Rust memory / logs between the two
  async steps. The plaintext only exists briefly in login_scalecloud() and
  again briefly inside scalecloud_credential_injection().


---

Backend Reference: apple_ecies_encrypt() (scalecloud.rs)

  Matches Apple's kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM.
  The iOS app decrypts with SecKeyCreateDecryptedData using the same algorithm
  constant — no manual crypto needed on the iOS side.

  Input:  device_pub_bytes (65-byte uncompressed P-256 point)
          plaintext (password bytes)

  1. EncodedPoint::from_bytes(device_pub_bytes)
     PublicKey::from_encoded_point(&point)  — parse device public key.
  2. EphemeralSecret::random(&mut rng)       — ephemeral P-256 keypair.
  3. ephemeral_secret.diffie_hellman(&device_pub) → raw shared secret (32 B).
  4. SHA-256(shared_secret || 0x00000001 || ephemeral_pub_65_bytes)
       → 32-byte key material.
  5. key_material[0..16]  = AES-128 key.
     key_material[16..32] = 16-byte IV (non-standard — normal GCM uses 12 B).
  6. Aes128GcmU16::new_from_slice(aes_key).encrypt(nonce, plaintext)
       → ciphertext + 16-byte GCM tag (appended by the library).

  Output wire format:
    ephemeral_pubkey (65 B) || ciphertext (N B) || GCM tag (16 B)

  Base64-standard-encoded before transmission.


---

INTERFACE CONTRACT (iOS app ↔ iloader)

When the app is launched
The app is launched by iloader via idevicedebug run com.scalecloud.app.
stdin and stdout are live pipes. The app must use them for the handshake.
This is not a normal user launch.

Phase 1 — App announces its public key (app → iloader, stdout)

  Generate transient P-256 keypair in Secure Enclave.
  Export public key as uncompressed point (65 bytes: 0x04 || X || Y).
  Base64-standard-encode it.
  Print to stdout:

    <bare-base64-public-key>\n
    SCALECLOUD_PUBKEY_READY\n

  The line immediately before SCALECLOUD_PUBKEY_READY is captured as the key.
  iloader tracks the last non-empty line seen before the sentinel.
  DO NOT prefix the key line (e.g. no "SCALECLOUD_PUBKEY:...") — bare base64 only.
  DO NOT print any other non-empty lines between the key and the sentinel.

Phase 2 — iloader sends the credential payload (iloader → app, stdin)

  iloader writes these 5 lines:

    <base64-encoded encrypted password>\n   ← ECIES-encrypted, see format below
    <plaintext email>\n
    http://toth-adattar.tailf2b093.ts.net:6969\n
    toth-adattar.tailf2b093.ts.net\n
    SCALECLOUD_PAYLOAD_COMPLETE\n

  Lines are positional, not key-value prefixed.
  Read by line number: 1=password, 2=email, 3=anisette URL, 4=tailscale host.

Phase 3 — App confirms receipt (app → iloader, stdout)

  After storing credentials:
    SCALECLOUD_CREDENTIALS_OK\n

  iloader waits for this. On receipt: waits 1 second, then kills idevicedebug.
  Do NOT print this before credentials are actually stored.

Encrypted password wire format

  Binary layout (before base64):
    [65 B]  ephemeral P-256 public key (uncompressed: 0x04 || X || Y)
    [N B]   AES-128-GCM ciphertext of the password
    [16 B]  AES-128-GCM authentication tag

  To decrypt (manual):
    1. First 65 bytes → ephemeral public key.
    2. ECDH(your_private_key, ephemeral_pubkey) → shared secret (32 B).
    3. SHA-256(shared_secret || 0x00000001 || ephemeral_pubkey_65_bytes)
         → 32-byte key material.
    4. key_material[0..16] = AES key, key_material[16..32] = 16-byte IV.
    5. AES-128-GCM decrypt with 16-byte nonce (not the standard 12-byte).

  iOS shortcut:
    SecKeyCreateDecryptedData(privateKey,
      kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM,
      encryptedData)
    This matches the wire format exactly. No manual decryption needed.

Things the app must NOT do
  - Print any non-empty lines to stdout between the pubkey line and SCALECLOUD_PUBKEY_READY.
  - Prefix the public key line (bare base64, nothing else on that line).
  - Parse the payload as key-value pairs — lines are positional.
  - Close stdin before reading SCALECLOUD_PAYLOAD_COMPLETE.
  - Print SCALECLOUD_CREDENTIALS_OK before credentials are actually stored.

Payload line 4 (Tailscale hostname)
  Line 4 is the Nextcloud server address for ScaleCloudApp's NCLogin flow.
  ScaleCloudRenew receives and logs it but does not persist it.
  ScaleCloudApp handles that separately through its own login UI.
