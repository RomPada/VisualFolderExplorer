# Visual Folder Explorer — Deployment / Розгортання

## English

### Recommended build for end users

Use `PublishWin64.bat` on a build/developer PC. It creates a self-contained `publish/win-x64-portable/` directory. Copy the **entire directory** to another Windows 10/11 x64 computer and run `VisualFolderExplorer.exe`. The target PC does not need .NET, the .NET SDK, Visual Studio, or NuGet access.

### Why the old build failed with NU1301

`dotnet run` performs NuGet restore before compiling. The project has no third-party NuGet packages, but NuGet still tried to reach the configured `https://api.nuget.org/v3/index.json` source (including vulnerability/audit metadata). A corporate firewall/socket policy blocked that request. v1.0.3 adds a local `NuGet.Config` that clears external package sources and disables NuGet audit for this project.

### Corporate PCs

A self-contained build removes runtime installation requirements, but it cannot and should not bypass organizational security policy. Defender, SmartScreen, AppLocker, WDAC, EDR, or application allowlists may still block unsigned or unapproved executables.

For managed deployment, prefer:

1. Self-contained **portable folder** build.
2. Authenticode signing with a certificate trusted by the organization.
3. IT approval/allowlisting by signed publisher, approved hash, or managed path according to company policy.
4. MSI/MSIX packaging and deployment through the organization's normal software-management tooling when broad installation is required.

The optional `PublishSingleFileWin64.bat` is convenient for personal PCs, but a single-file self-extracting bundle may be less transparent to some enterprise EDR/application-control systems than the normal portable folder.

## Українська

### Рекомендована збірка для користувача

На ПК розробника/збірки запустіть `PublishWin64.bat`. Він створить self-contained папку `publish/win-x64-portable/`. Скопіюйте **всю папку** на інший Windows 10/11 x64 ПК і запускайте `VisualFolderExplorer.exe`. На цільовому ПК не потрібні .NET, .NET SDK, Visual Studio або доступ до NuGet.

### Чому стара збірка падала з NU1301

`dotnet run` перед компіляцією виконує NuGet restore. У проєкті немає сторонніх NuGet-пакетів, але NuGet усе одно намагався звертатися до налаштованого `https://api.nuget.org/v3/index.json` (у тому числі для audit/vulnerability metadata). Корпоративна мережева/socket-політика заблокувала цей запит. У v1.0.3 додано локальний `NuGet.Config`, який очищає зовнішні package sources і вимикає NuGet audit для цього проєкту.

### Корпоративні ПК

Self-contained збірка прибирає потребу встановлювати runtime, але не може і не повинна обходити корпоративні політики безпеки. Defender, SmartScreen, AppLocker, WDAC, EDR або application allowlist можуть блокувати непідписані чи неузгоджені програми.

Для керованого розгортання рекомендовано:

1. Self-contained **portable folder**.
2. Authenticode-підпис сертифікатом, якому довіряє організація.
3. Офіційний IT allowlisting за підписаним видавцем, погодженим hash або керованим шляхом відповідно до політики компанії.
4. Для масового встановлення — MSI/MSIX і розгортання через стандартні корпоративні інструменти.

`PublishSingleFileWin64.bat` зручний для персональних ПК, але self-extracting single-file bundle може бути менш прозорим для окремих EDR/application-control систем, ніж звичайна portable папка.
