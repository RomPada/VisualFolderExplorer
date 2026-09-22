Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:RootFolder = $null
$script:CurrentFolder = $null
$script:TextFiles = @()
$script:TextIndex = -1
$script:ImageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff', '.webp')
$script:AppVersion = '0.3.1'
$script:PreviewZoomed = $false
$script:PreviewImagePath = $null
$script:IsLoadingText = $false
$script:TextDirty = $false
$script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
$script:SettingsFolder = Join-Path $env:LOCALAPPDATA 'VisualFolderExplorer'
$script:SettingsPath = Join-Path $script:SettingsFolder 'settings.json'

# Shared file-operation actions used by dynamically created context menus.
$script:SetFileClipboardAction = {
    param([string]$Path, [bool]$Cut)
    try {
        $data = New-Object System.Windows.DataObject
        $files = New-Object System.Collections.Specialized.StringCollection
        [void]$files.Add($Path)
        $data.SetFileDropList($files)

        # Explorer understands Preferred DropEffect: 1 = copy, 2 = move/cut.
        [byte[]]$effect = if ($Cut) { 2,0,0,0 } else { 1,0,0,0 }
        $stream = [System.IO.MemoryStream]::new($effect)
        $data.SetData('Preferred DropEffect', $stream)
        [System.Windows.Clipboard]::SetDataObject($data, $true)
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "Не вдалося помістити файл у буфер обміну.`r`n`r`n$($_.Exception.Message)",
            'Помилка буфера обміну',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

$script:SendFileToRecycleBinAction = {
    param([string]$Path)
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
            [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException
        )
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "Не вдалося перемістити файл до кошика.`r`n`r`n$($_.Exception.Message)",
            'Помилка видалення',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Visual Folder Explorer v0.3.1" Height="820" Width="1420"
        MinHeight="620" MinWidth="980"
        WindowStartupLocation="CenterScreen"
        Background="#F4F6F8" FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="ToolbarButton" TargetType="Button">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#1B1F23"/>
            <Setter Property="BorderBrush" Value="#D9DEE3"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#EEF3F7"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavButton" TargetType="Button" BasedOn="{StaticResource ToolbarButton}">
            <Setter Property="MinWidth" Value="44"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="Padding" Value="10,5"/>
        </Style>
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="White" CornerRadius="12" Padding="10" BorderBrush="#E3E7EA" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Button x:Name="BackButton" Grid.Column="0" Content="←" Style="{StaticResource NavButton}" ToolTip="Назад"/>
                <Button x:Name="UpButton" Grid.Column="1" Content="↑" Style="{StaticResource NavButton}" ToolTip="На рівень вище"/>
                <Button x:Name="HomeButton" Grid.Column="2" Content="⌂" Style="{StaticResource NavButton}" ToolTip="До кореневої папки"/>

                <Border Grid.Column="3" Background="#F5F7F9" CornerRadius="8" Margin="0,0,10,0" Padding="10,7">
                    <TextBlock x:Name="PathText" Text="Оберіть кореневу папку" Foreground="#4A525A" FontSize="14" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                </Border>

                <Button x:Name="ChooseRootButton" Grid.Column="4" Content="Обрати папку" Style="{StaticResource ToolbarButton}" Margin="0"/>
            </Grid>
        </Border>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="260" MinWidth="190"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*" MinWidth="380"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="390" MinWidth="300" MaxWidth="560"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Text="Папки" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23"/>
                    <ListBox x:Name="FolderList" Grid.Row="2" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                        <ListBox.ItemContainerStyle>
                            <Style TargetType="ListBoxItem">
                                <Setter Property="Padding" Value="8,9"/>
                                <Setter Property="Margin" Value="0,1"/>
                                <Setter Property="Cursor" Value="Hand"/>
                                <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                                <Setter Property="Template">
                                    <Setter.Value>
                                        <ControlTemplate TargetType="ListBoxItem">
                                            <Border x:Name="Bd" Background="Transparent" CornerRadius="7" Padding="{TemplateBinding Padding}">
                                                <ContentPresenter/>
                                            </Border>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsMouseOver" Value="True">
                                                    <Setter TargetName="Bd" Property="Background" Value="#F1F4F6"/>
                                                </Trigger>
                                                <Trigger Property="IsSelected" Value="True">
                                                    <Setter TargetName="Bd" Property="Background" Value="#E7F0F8"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </Setter.Value>
                                </Setter>
                            </Style>
                        </ListBox.ItemContainerStyle>
                    </ListBox>
                </Grid>
            </Border>

            <GridSplitter Grid.Column="1" Width="8" HorizontalAlignment="Stretch" Background="Transparent"/>

            <Border Grid.Column="2" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <DockPanel>
                        <TextBlock Text="Зображення" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23" DockPanel.Dock="Left"/>
                        <TextBlock x:Name="ImageCountText" Foreground="#7A838B" FontSize="13" HorizontalAlignment="Right"/>
                    </DockPanel>
                    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <WrapPanel x:Name="ImagePanel" Orientation="Horizontal"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <GridSplitter Grid.Column="3" Width="8" HorizontalAlignment="Stretch" Background="Transparent"/>

            <Border Grid.Column="4" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="14">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="ReturnToTextButton" Grid.Column="0" Content="До тексту" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0" Padding="9,5" FontSize="12" Visibility="Collapsed" ToolTip="Повернутися до текстового опису"/>
                        <TextBlock x:Name="SidePanelTitle" Grid.Column="1" Text="Текст" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23" VerticalAlignment="Center"/>
                        <TextBlock x:Name="TextFileName" Grid.Column="2" Margin="10,0,10,0" Foreground="#7A838B" FontSize="12" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" TextAlignment="Right"/>
                        <Button x:Name="SaveTextButton" Grid.Column="3" Content="Зберегти" Style="{StaticResource ToolbarButton}" Margin="0" Padding="10,5" FontSize="12" IsEnabled="False" ToolTip="Зберегти зміни (Ctrl+S)"/>
                    </Grid>

                    <Grid Grid.Row="2">
                        <Border x:Name="TextContentBorder" BorderBrush="#E6EAED" BorderThickness="1" CornerRadius="8" Background="#FBFCFD">
                            <TextBox x:Name="TextViewer" BorderThickness="0" Background="Transparent" Padding="12" TextWrapping="Wrap"
                                     AcceptsReturn="True" AcceptsTab="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                                     IsReadOnly="True" FontSize="14" Foreground="#252A2E" SpellCheck.IsEnabled="False"/>
                        </Border>

                        <Border x:Name="PreviewContentBorder" BorderBrush="#E6EAED" BorderThickness="1" CornerRadius="8" Background="#101214" Visibility="Collapsed" ClipToBounds="True">
                            <Grid>
                                <Image x:Name="PreviewImage" Stretch="Uniform" Margin="8"/>
                                <TextBlock x:Name="PreviewError" Text="Не вдалося відкрити прев'ю." Foreground="White" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <Grid x:Name="TextNavigationPanel" Grid.Row="4">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="PrevTextButton" Grid.Column="0" Content="←" Style="{StaticResource NavButton}" ToolTip="Попередній текстовий файл"/>
                        <TextBlock x:Name="TextCounter" Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#66707A" FontSize="13"/>
                        <Button x:Name="NextTextButton" Grid.Column="2" Content="→" Style="{StaticResource NavButton}" Margin="0" ToolTip="Наступний текстовий файл"/>
                    </Grid>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="3" x:Name="StatusText" Margin="4,10,0,0" Foreground="#6D767E" FontSize="12" Text="Готово"/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$BackButton      = $window.FindName('BackButton')
$UpButton        = $window.FindName('UpButton')
$HomeButton      = $window.FindName('HomeButton')
$ChooseRootButton= $window.FindName('ChooseRootButton')
$PathText        = $window.FindName('PathText')
$FolderList      = $window.FindName('FolderList')
$ImagePanel      = $window.FindName('ImagePanel')
$ImageCountText  = $window.FindName('ImageCountText')
$TextViewer      = $window.FindName('TextViewer')
$TextFileName    = $window.FindName('TextFileName')
$SaveTextButton  = $window.FindName('SaveTextButton')
$SidePanelTitle  = $window.FindName('SidePanelTitle')
$ReturnToTextButton = $window.FindName('ReturnToTextButton')
$TextContentBorder = $window.FindName('TextContentBorder')
$PreviewContentBorder = $window.FindName('PreviewContentBorder')
$PreviewImage    = $window.FindName('PreviewImage')
$PreviewError    = $window.FindName('PreviewError')
$TextNavigationPanel = $window.FindName('TextNavigationPanel')
$PrevTextButton  = $window.FindName('PrevTextButton')
$NextTextButton  = $window.FindName('NextTextButton')
$TextCounter     = $window.FindName('TextCounter')
$StatusText      = $window.FindName('StatusText')

$script:History = New-Object System.Collections.Generic.List[string]

function Get-NaturalSortKey([string]$name) {
    return [regex]::Replace($name, '\d+', { param($m) $m.Value.PadLeft(12, '0') })
}

function New-BitmapImage([string]$path, [int]$decodeWidth = 0) {
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
        if ($decodeWidth -gt 0) { $bitmap.DecodePixelWidth = $decodeWidth }
        $bitmap.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    } catch {
        return $null
    }
}

function Save-Settings {
    try {
        if (-not (Test-Path -LiteralPath $script:SettingsFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $script:SettingsFolder -Force | Out-Null
        }

        $settings = [ordered]@{
            Version = $script:AppVersion
            RootFolder = $script:RootFolder
            CurrentFolder = $script:CurrentFolder
            History = @($script:History)
        }
        $settings | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8 -Force
    } catch {
        # Налаштування не повинні заважати основній роботі програми.
    }
}

function Load-Settings {
    try {
        if (-not (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)) { return $false }
        $raw = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
        $saved = $raw | ConvertFrom-Json -ErrorAction Stop

        $savedRoot = [string]$saved.RootFolder
        $savedCurrent = [string]$saved.CurrentFolder

        if ([string]::IsNullOrWhiteSpace($savedRoot) -or -not (Test-Path -LiteralPath $savedRoot -PathType Container)) {
            return $false
        }

        $script:RootFolder = (Resolve-Path -LiteralPath $savedRoot).Path

        # The last opened folder is restored even if the user navigated above the
        # original home/root folder. This makes the app behave more like Explorer.
        if (-not [string]::IsNullOrWhiteSpace($savedCurrent) -and (Test-Path -LiteralPath $savedCurrent -PathType Container)) {
            $script:CurrentFolder = (Resolve-Path -LiteralPath $savedCurrent).Path
        }

        if (-not $script:CurrentFolder) { $script:CurrentFolder = $script:RootFolder }

        # Restore navigation history so the Back button is usable immediately.
        $script:History.Clear()
        if ($null -ne $saved.History) {
            foreach ($historyPath in @($saved.History)) {
                $candidate = [string]$historyPath
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and
                    (Test-Path -LiteralPath $candidate -PathType Container)) {
                    $resolvedCandidate = (Resolve-Path -LiteralPath $candidate).Path
                    if (-not $resolvedCandidate.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $script:History.Add($resolvedCandidate)
                    }
                }
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Get-TextFileData([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $encoding = $null
    $offset = 0

    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        $encoding = [System.Text.UTF32Encoding]::new($true, $true)
        $offset = 4
    } elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        $encoding = [System.Text.UTF32Encoding]::new($false, $true)
        $offset = 4
    } elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true)
        $offset = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.Encoding]::BigEndianUnicode
        $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.Encoding]::Unicode
        $offset = 2
    } else {
        try {
            $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
            [void]$strictUtf8.GetString($bytes)
            $encoding = [System.Text.UTF8Encoding]::new($false)
        } catch {
            $encoding = [System.Text.Encoding]::Default
        }
    }

    $length = $bytes.Length - $offset
    if ($length -lt 0) { $length = 0 }
    $text = $encoding.GetString($bytes, $offset, $length)
    return [pscustomobject]@{ Text = $text; Encoding = $encoding }
}

function Set-TextDirty([bool]$dirty) {
    $script:TextDirty = $dirty
    $hasFile = ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0 -and $script:TextIndex -lt $script:TextFiles.Count)
    $SaveTextButton.IsEnabled = ($dirty -and $hasFile)

    if ($hasFile) {
        $name = $script:TextFiles[$script:TextIndex].Name
        $TextFileName.Text = if ($dirty) { "$name  • незбережено" } else { $name }
    } elseif ($PreviewContentBorder.Visibility -ne 'Visible') {
        $TextFileName.Text = ''
    }
}

function Save-CurrentTextFile {
    if ($script:TextFiles.Count -eq 0 -or $script:TextIndex -lt 0 -or $script:TextIndex -ge $script:TextFiles.Count) {
        return $false
    }

    $file = $script:TextFiles[$script:TextIndex]
    try {
        $encoding = $script:CurrentTextEncoding
        if ($null -eq $encoding) { $encoding = [System.Text.UTF8Encoding]::new($false) }
        [System.IO.File]::WriteAllText($file.FullName, $TextViewer.Text, $encoding)
        Set-TextDirty $false
        $StatusText.Text = "Збережено: $($file.Name)"
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "Не вдалося зберегти файл:`r`n$($file.FullName)`r`n`r`n$($_.Exception.Message)",
            'Помилка збереження',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

function Confirm-PendingTextChanges {
    if (-not $script:TextDirty) { return $true }
    if ($script:TextFiles.Count -eq 0 -or $script:TextIndex -lt 0) { return $true }

    $file = $script:TextFiles[$script:TextIndex]
    $result = [System.Windows.MessageBox]::Show(
        "У файлі '$($file.Name)' є незбережені зміни.`r`n`r`nЗберегти їх?",
        'Незбережені зміни',
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        return (Save-CurrentTextFile)
    }
    if ($result -eq [System.Windows.MessageBoxResult]::No) {
        return $true
    }
    return $false
}

function Show-TextMode {
    $TextContentBorder.Visibility = 'Visible'
    $PreviewContentBorder.Visibility = 'Collapsed'
    $TextNavigationPanel.Visibility = 'Visible'
    $ReturnToTextButton.Visibility = 'Collapsed'
    $SaveTextButton.Visibility = 'Visible'
    $SidePanelTitle.Text = 'Текст'
    $PreviewImage.Source = $null
    $PreviewImage.RenderTransform = [System.Windows.Media.ScaleTransform]::new(1, 1)
    $PreviewImage.Cursor = [System.Windows.Input.Cursors]::Hand
    $script:PreviewZoomed = $false
    $script:PreviewImagePath = $null
    $PreviewError.Visibility = 'Collapsed'
    if ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0) {
        Set-TextDirty $script:TextDirty
    } else {
        $TextFileName.Text = ''
    }
}

function Update-TextNavigation {
    $count = $script:TextFiles.Count
    $script:IsLoadingText = $true
    try {
        if ($count -eq 0) {
            $TextViewer.IsReadOnly = $true
            $TextViewer.Text = 'У цій папці немає файлів .txt або .md.'
            $TextFileName.Text = ''
            $TextCounter.Text = '0 / 0'
            $PrevTextButton.IsEnabled = $false
            $NextTextButton.IsEnabled = $false
            $script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
            Set-TextDirty $false
            return
        }

        if ($script:TextIndex -lt 0) { $script:TextIndex = 0 }
        if ($script:TextIndex -ge $count) { $script:TextIndex = $count - 1 }

        $file = $script:TextFiles[$script:TextIndex]
        try {
            $data = Get-TextFileData $file.FullName
            $TextViewer.Text = $data.Text
            $script:CurrentTextEncoding = $data.Encoding
            $TextViewer.IsReadOnly = $false
        } catch {
            $TextViewer.Text = "Не вдалося прочитати файл.`r`n`r`n$($_.Exception.Message)"
            $TextViewer.IsReadOnly = $true
            $script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
        }

        $TextCounter.Text = "{0} / {1}" -f ($script:TextIndex + 1), $count
        $PrevTextButton.IsEnabled = ($count -gt 1)
        $NextTextButton.IsEnabled = ($count -gt 1)
        Set-TextDirty $false
    } finally {
        $script:IsLoadingText = $false
    }
}

function Load-TextFiles([string]$folder) {
    $script:TextFiles = @()
    $script:TextIndex = -1

    try {
        $files = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction Stop | Where-Object {
            $_.Extension -ieq '.txt' -or $_.Extension -ieq '.md'
        })
        if ($files.Count -gt 0) {
            $folderName = Split-Path -Leaf $folder
            $preferredTxt = "$folderName`_текст.txt"
            $preferredMd = "$folderName`_текст.md"
            $script:TextFiles = @($files | Sort-Object @{ Expression = {
                if ($_.Name -ieq $preferredTxt) { 0 }
                elseif ($_.Name -ieq $preferredMd) { 1 }
                else { 2 }
            } }, @{ Expression = { Get-NaturalSortKey $_.Name } })
            $script:TextIndex = 0
        }
    } catch {
        $StatusText.Text = "Помилка читання текстових файлів: $($_.Exception.Message)"
    }

    Update-TextNavigation
}

function Open-TextFileByPath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }

    $targetIndex = -1
    for ($i = 0; $i -lt $script:TextFiles.Count; $i++) {
        if ($script:TextFiles[$i].FullName.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIndex = $i
            break
        }
    }

    if ($targetIndex -lt 0) {
        Load-TextFiles $script:CurrentFolder
        for ($i = 0; $i -lt $script:TextFiles.Count; $i++) {
            if ($script:TextFiles[$i].FullName.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
                $targetIndex = $i
                break
            }
        }
    }

    if ($targetIndex -lt 0) { return $false }
    if ($targetIndex -ne $script:TextIndex -and -not (Confirm-PendingTextChanges)) { return $false }

    $script:TextIndex = $targetIndex
    Update-TextNavigation
    Show-TextMode
    $StatusText.Text = "Відкрито текстовий файл: $([System.IO.Path]::GetFileName($path))"
    return $true
}

function Add-ImageTile([System.IO.FileInfo]$file) {
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 190
    $tile.Height = 178
    $tile.Margin = '0,0,12,12'
    $tile.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F7F8FA')
    $tile.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E2E6EA')
    $tile.BorderThickness = 1
    $tile.CornerRadius = 10
    $tile.Cursor = [System.Windows.Input.Cursors]::Hand
    $tile.ToolTip = $file.Name
    $tile.Tag = $file.FullName

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = 7
    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $grid.RowDefinitions.Add($row1)
    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = [System.Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($row2)

    $imageBorder = New-Object System.Windows.Controls.Border
    $imageBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#ECEFF2')
    $imageBorder.CornerRadius = 7
    $imageBorder.ClipToBounds = $true

    $img = New-Object System.Windows.Controls.Image
    $img.Stretch = 'Uniform'
    $img.HorizontalAlignment = 'Stretch'
    $img.VerticalAlignment = 'Stretch'

    $bitmap = New-BitmapImage $file.FullName 420
    if ($null -ne $bitmap) {
        $img.Source = $bitmap
    } else {
        $fallback = New-Object System.Windows.Controls.TextBlock
        $fallback.Text = "Немає`nпрев'ю"
        $fallback.TextAlignment = 'Center'
        $fallback.HorizontalAlignment = 'Center'
        $fallback.VerticalAlignment = 'Center'
        $fallback.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#7A838B')
        $imageBorder.Child = $fallback
    }

    if ($null -eq $imageBorder.Child) { $imageBorder.Child = $img }
    [System.Windows.Controls.Grid]::SetRow($imageBorder, 0)
    $grid.Children.Add($imageBorder) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $file.Name
    $label.Margin = '3,7,3,0'
    $label.FontSize = 12
    $label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#3C434A')
    $label.TextTrimming = 'CharacterEllipsis'
    $label.HorizontalAlignment = 'Stretch'
    [System.Windows.Controls.Grid]::SetRow($label, 1)
    $grid.Children.Add($label) | Out-Null

    $tile.Child = $grid
    $tile.Add_MouseLeftButtonUp($script:ImageTileClickHandler)

    $menu = New-Object System.Windows.Controls.ContextMenu

    $cut = New-Object System.Windows.Controls.MenuItem
    $cut.Header = 'Вирізати'
    $cut.Tag = $file.FullName
    $cut.Add_Click($script:ImageCutHandler)
    [void]$menu.Items.Add($cut)

    $copy = New-Object System.Windows.Controls.MenuItem
    $copy.Header = 'Копіювати'
    $copy.Tag = $file.FullName
    $copy.Add_Click($script:ImageCopyHandler)
    [void]$menu.Items.Add($copy)

    [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))

    $rename = New-Object System.Windows.Controls.MenuItem
    $rename.Header = 'Перейменувати'
    $rename.Tag = $file.FullName
    $rename.Add_Click($script:ImageRenameHandler)
    [void]$menu.Items.Add($rename)

    $delete = New-Object System.Windows.Controls.MenuItem
    $delete.Header = 'Видалити'
    $delete.Tag = $file.FullName
    $delete.Add_Click($script:ImageDeleteHandler)
    [void]$menu.Items.Add($delete)

    $tile.ContextMenu = $menu
    $ImagePanel.Children.Add($tile) | Out-Null
}

function Load-Images([string]$folder) {
    $ImagePanel.Children.Clear()
    try {
        $images = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction Stop | Where-Object {
            $script:ImageExtensions -contains $_.Extension.ToLowerInvariant()
        } | Sort-Object { Get-NaturalSortKey $_.Name })

        foreach ($imgFile in $images) { Add-ImageTile $imgFile }
        $ImageCountText.Text = if ($images.Count -eq 1) { '1 файл' } else { "$($images.Count) файлів" }

        if ($images.Count -eq 0) {
            $empty = New-Object System.Windows.Controls.TextBlock
            $empty.Text = 'У цій папці немає зображень.'
            $empty.Margin = 8
            $empty.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#7A838B')
            $empty.FontSize = 14
            $ImagePanel.Children.Add($empty) | Out-Null
        }
    } catch {
        $ImageCountText.Text = '0 файлів'
        $StatusText.Text = "Помилка читання зображень: $($_.Exception.Message)"
    }
}

function Load-Folders([string]$folder) {
    $FolderList.Items.Clear()
    try {
        $dirs = @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction Stop | Sort-Object { Get-NaturalSortKey $_.Name })
        foreach ($dir in $dirs) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Content = "📁  $($dir.Name)"
            $item.Tag = [pscustomobject]@{ Type = 'Folder'; Path = $dir.FullName }
            $FolderList.Items.Add($item) | Out-Null
        }

        $textFiles = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction Stop | Where-Object {
            $_.Extension -ieq '.txt' -or $_.Extension -ieq '.md'
        } | Sort-Object { Get-NaturalSortKey $_.Name })

        foreach ($file in $textFiles) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $icon = if ($file.Extension -ieq '.md') { '📝' } else { '📄' }
            $item.Content = "$icon  $($file.Name)"
            $item.Tag = [pscustomobject]@{ Type = 'Text'; Path = $file.FullName }

            $menu = New-Object System.Windows.Controls.ContextMenu

            $open = New-Object System.Windows.Controls.MenuItem
            $open.Header = 'Відкрити'
            $open.Tag = $file.FullName
            $open.Add_Click($script:TextOpenHandler)
            [void]$menu.Items.Add($open)

            [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))

            $cut = New-Object System.Windows.Controls.MenuItem
            $cut.Header = 'Вирізати'
            $cut.Tag = $file.FullName
            $cut.Add_Click($script:TextCutHandler)
            [void]$menu.Items.Add($cut)

            $copy = New-Object System.Windows.Controls.MenuItem
            $copy.Header = 'Копіювати'
            $copy.Tag = $file.FullName
            $copy.Add_Click($script:TextCopyHandler)
            [void]$menu.Items.Add($copy)

            [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))

            $rename = New-Object System.Windows.Controls.MenuItem
            $rename.Header = 'Перейменувати'
            $rename.Tag = $file.FullName
            $rename.Add_Click($script:TextRenameHandler)
            [void]$menu.Items.Add($rename)

            $delete = New-Object System.Windows.Controls.MenuItem
            $delete.Header = 'Видалити'
            $delete.Tag = $file.FullName
            $delete.Add_Click($script:TextDeleteHandler)
            [void]$menu.Items.Add($delete)

            $item.ContextMenu = $menu
            $FolderList.Items.Add($item) | Out-Null
        }
    } catch {
        $StatusText.Text = "Помилка читання папок і текстових файлів: $($_.Exception.Message)"
    }
}

function Update-NavigationButtons {
    $BackButton.IsEnabled = ($script:History.Count -gt 0)
    $HomeButton.IsEnabled = [bool]$script:RootFolder

    if ($script:CurrentFolder) {
        $parent = Split-Path -Parent $script:CurrentFolder
        $UpButton.IsEnabled = (-not [string]::IsNullOrWhiteSpace($parent) -and
                               (Test-Path -LiteralPath $parent -PathType Container) -and
                               -not $parent.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase))
    } else {
        $UpButton.IsEnabled = $false
    }
}

function Ensure-StartupNavigationHistory {
    # A fresh app session has no in-memory navigation history. Seed Back with the
    # current folder's parent so the toolbar is useful immediately after restore.
    if ($script:History.Count -eq 0 -and $script:CurrentFolder) {
        $parent = Split-Path -Parent $script:CurrentFolder
        if (-not [string]::IsNullOrWhiteSpace($parent) -and
            (Test-Path -LiteralPath $parent -PathType Container) -and
            -not $parent.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:History.Add((Resolve-Path -LiteralPath $parent).Path)
        }
    }
    Update-NavigationButtons
}

function Navigate-To([string]$folder, [bool]$addHistory = $true, [bool]$skipUnsavedCheck = $false) {
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) { return $false }
    if (-not $skipUnsavedCheck -and -not (Confirm-PendingTextChanges)) { return $false }

    if ($addHistory -and $script:CurrentFolder -and $script:CurrentFolder -ne $folder) {
        $script:History.Add($script:CurrentFolder)
    }

    $script:CurrentFolder = (Resolve-Path -LiteralPath $folder).Path
    $PathText.Text = $script:CurrentFolder
    $PathText.ToolTip = $script:CurrentFolder
    $StatusText.Text = "Відкрито: $script:CurrentFolder"
    Show-TextMode

    Load-Folders $script:CurrentFolder
    Load-Images $script:CurrentFolder
    Load-TextFiles $script:CurrentFolder

    Update-NavigationButtons
    Save-Settings
    return $true
}

function Choose-RootFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Оберіть кореневу папку з вашими матеріалами'
    $dialog.ShowNewFolderButton = $true
    if ($script:RootFolder -and (Test-Path -LiteralPath $script:RootFolder)) {
        $dialog.SelectedPath = $script:RootFolder
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (-not (Confirm-PendingTextChanges)) { return }
        $script:RootFolder = $dialog.SelectedPath
        $script:History.Clear()
        Navigate-To $script:RootFolder $false $true | Out-Null
    }
}

# ---- Shared UI handlers -----------------------------------------------------
# These handlers live in the main script scope (rather than per-tile closures),
# which keeps them reliable when the app is launched through the BAT wrapper.

$script:ImageTileClickHandler = {
    param($sender, $e)
    $imagePath = [string]$sender.Tag
    if ([string]::IsNullOrWhiteSpace($imagePath) -or -not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { return }

    try {
        $bitmapPreview = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapPreview.BeginInit()
        $bitmapPreview.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmapPreview.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
        $bitmapPreview.DecodePixelWidth = 1800
        $bitmapPreview.UriSource = New-Object System.Uri($imagePath, [System.UriKind]::Absolute)
        $bitmapPreview.EndInit()
        $bitmapPreview.Freeze()

        $PreviewImage.Source = $bitmapPreview
        $PreviewError.Visibility = 'Collapsed'
    } catch {
        $PreviewImage.Source = $null
        $PreviewError.Visibility = 'Visible'
    }

    $script:PreviewImagePath = $imagePath
    $script:PreviewZoomed = $false
    $PreviewImage.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    $PreviewImage.RenderTransform = [System.Windows.Media.ScaleTransform]::new(1, 1)
    $PreviewImage.Cursor = [System.Windows.Input.Cursors]::Hand

    $TextContentBorder.Visibility = 'Collapsed'
    $PreviewContentBorder.Visibility = 'Visible'
    $TextNavigationPanel.Visibility = 'Collapsed'
    $ReturnToTextButton.Visibility = 'Visible'
    $SaveTextButton.Visibility = 'Collapsed'
    $SidePanelTitle.Text = "Прев'ю"
    $TextFileName.Text = [System.IO.Path]::GetFileName($imagePath)
    $StatusText.Text = 'Лівий клік по превʼю: збільшити / повернути розмір'
    $e.Handled = $true
}

$script:ImageCutHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $true) {
        $StatusText.Text = "Вирізано до буфера обміну: $([System.IO.Path]::GetFileName($path))"
    }
}

$script:ImageCopyHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $false) {
        $StatusText.Text = "Скопійовано до буфера обміну: $([System.IO.Path]::GetFileName($path))"
    }
}

$script:ImageRenameHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }

    $oldName = [System.IO.Path]::GetFileName($path)
    $newName = [Microsoft.VisualBasic.Interaction]::InputBox(
        'Введіть нову назву файлу:',
        'Перейменувати зображення',
        $oldName
    )
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $oldName) { return }

    if ([System.IO.Path]::GetFileName($newName) -ne $newName -or $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show('Назва файлу містить недопустимі символи.', 'Некоректна назва') | Out-Null
        return
    }

    $destination = Join-Path ([System.IO.Path]::GetDirectoryName($path)) $newName
    if (Test-Path -LiteralPath $destination) {
        [System.Windows.MessageBox]::Show('Файл з такою назвою вже існує.', 'Перейменування') | Out-Null
        return
    }

    try {
        Move-Item -LiteralPath $path -Destination $destination -ErrorAction Stop
        if ($script:PreviewImagePath -and $script:PreviewImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:PreviewImagePath = $destination
            $TextFileName.Text = $newName
        }
        Load-Images $script:CurrentFolder
        $StatusText.Text = "Перейменовано: $newName"
    } catch {
        [System.Windows.MessageBox]::Show("Не вдалося перейменувати файл.`r`n`r`n$($_.Exception.Message)", 'Помилка') | Out-Null
    }
}

$script:ImageDeleteHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    $name = [System.IO.Path]::GetFileName($path)

    $answer = [System.Windows.MessageBox]::Show(
        "Перемістити '$name' до кошика?",
        'Видалити зображення',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    if (& $script:SendFileToRecycleBinAction $path) {
        if ($script:PreviewImagePath -and $script:PreviewImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            Show-TextMode
        }
        Load-Images $script:CurrentFolder
        $StatusText.Text = "Переміщено до кошика: $name"
    }
}

$script:TextOpenHandler = {
    param($sender, $e)
    Open-TextFileByPath ([string]$sender.Tag) | Out-Null
}

$script:TextCutHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $true) {
        $StatusText.Text = "Вирізано до буфера обміну: $([System.IO.Path]::GetFileName($path))"
    }
}

$script:TextCopyHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $false) {
        $StatusText.Text = "Скопійовано до буфера обміну: $([System.IO.Path]::GetFileName($path))"
    }
}

$script:TextRenameHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $oldName = [System.IO.Path]::GetFileName($path)
    $newName = [Microsoft.VisualBasic.Interaction]::InputBox(
        'Введіть нову назву файлу:',
        'Перейменувати текстовий файл',
        $oldName
    )
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $oldName) { return }

    if ([System.IO.Path]::GetFileName($newName) -ne $newName -or $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show('Назва файлу містить недопустимі символи.', 'Некоректна назва') | Out-Null
        return
    }

    $destination = Join-Path ([System.IO.Path]::GetDirectoryName($path)) $newName
    if (Test-Path -LiteralPath $destination) {
        [System.Windows.MessageBox]::Show('Файл з такою назвою вже існує.', 'Перейменування') | Out-Null
        return
    }

    try {
        Move-Item -LiteralPath $path -Destination $destination -ErrorAction Stop
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        if ([System.IO.Path]::GetExtension($destination) -ieq '.txt' -or [System.IO.Path]::GetExtension($destination) -ieq '.md') {
            Open-TextFileByPath $destination | Out-Null
        }
        $StatusText.Text = "Перейменовано: $newName"
    } catch {
        [System.Windows.MessageBox]::Show("Не вдалося перейменувати файл.`r`n`r`n$($_.Exception.Message)", 'Помилка') | Out-Null
    }
}

$script:TextDeleteHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $name = [System.IO.Path]::GetFileName($path)

    $answer = [System.Windows.MessageBox]::Show(
        "Перемістити '$name' до кошика?",
        'Видалити текстовий файл',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    if (& $script:SendFileToRecycleBinAction $path) {
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Show-TextMode
        $StatusText.Text = "Переміщено до кошика: $name"
    }
}

$script:CreateTxtHandler = {
    param($sender, $e)
    if (-not $script:CurrentFolder) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Назва нового TXT-файлу:', 'Створити TXT', 'Новий файл.txt')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if (-not $name.EndsWith('.txt', [System.StringComparison]::OrdinalIgnoreCase)) { $name += '.txt' }

    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show('Назва файлу містить недопустимі символи.', 'Некоректна назва') | Out-Null
        return
    }

    $path = Join-Path $script:CurrentFolder $name
    if (Test-Path -LiteralPath $path) {
        [System.Windows.MessageBox]::Show('Файл з такою назвою вже існує.', 'Створення файлу') | Out-Null
        return
    }

    try {
        [System.IO.File]::WriteAllText($path, '', [System.Text.UTF8Encoding]::new($false))
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Open-TextFileByPath $path | Out-Null
        $StatusText.Text = "Створено: $name"
    } catch {
        [System.Windows.MessageBox]::Show("Не вдалося створити файл.`r`n`r`n$($_.Exception.Message)", 'Помилка') | Out-Null
    }
}

$script:CreateMdHandler = {
    param($sender, $e)
    if (-not $script:CurrentFolder) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Назва нового Markdown-файлу:', 'Створити Markdown', 'Новий файл.md')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if (-not $name.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) { $name += '.md' }

    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show('Назва файлу містить недопустимі символи.', 'Некоректна назва') | Out-Null
        return
    }

    $path = Join-Path $script:CurrentFolder $name
    if (Test-Path -LiteralPath $path) {
        [System.Windows.MessageBox]::Show('Файл з такою назвою вже існує.', 'Створення файлу') | Out-Null
        return
    }

    try {
        [System.IO.File]::WriteAllText($path, '', [System.Text.UTF8Encoding]::new($false))
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Open-TextFileByPath $path | Out-Null
        $StatusText.Text = "Створено: $name"
    } catch {
        [System.Windows.MessageBox]::Show("Не вдалося створити файл.`r`n`r`n$($_.Exception.Message)", 'Помилка') | Out-Null
    }
}

# Context menu shown only when the user right-clicks an empty area in "Папки".
$script:CreateTextMenu = New-Object System.Windows.Controls.ContextMenu
$createTxtMenuItem = New-Object System.Windows.Controls.MenuItem
$createTxtMenuItem.Header = 'Створити TXT-файл'
$createTxtMenuItem.Add_Click($script:CreateTxtHandler)
[void]$script:CreateTextMenu.Items.Add($createTxtMenuItem)

$createMdMenuItem = New-Object System.Windows.Controls.MenuItem
$createMdMenuItem.Header = 'Створити Markdown-файл (.md)'
$createMdMenuItem.Add_Click($script:CreateMdHandler)
[void]$script:CreateTextMenu.Items.Add($createMdMenuItem)

$ChooseRootButton.Add_Click({ Choose-RootFolder })
$ReturnToTextButton.Add_Click({ Show-TextMode })
$SaveTextButton.Add_Click({ Save-CurrentTextFile | Out-Null })

$TextViewer.Add_TextChanged({
    if (-not $script:IsLoadingText -and -not $TextViewer.IsReadOnly -and $script:TextFiles.Count -gt 0) {
        Set-TextDirty $true
        $StatusText.Text = 'Є незбережені зміни'
    }
})

$FolderList.Add_MouseDoubleClick({
    if (-not $FolderList.SelectedItem -or -not $FolderList.SelectedItem.Tag) { return }
    $tag = $FolderList.SelectedItem.Tag
    if ($tag.Type -eq 'Folder') {
        Navigate-To ([string]$tag.Path)
    } elseif ($tag.Type -eq 'Text') {
        Open-TextFileByPath ([string]$tag.Path) | Out-Null
    }
})

$FolderList.Add_PreviewMouseRightButtonUp({
    param($sender, $e)
    try {
        $source = $e.OriginalSource -as [System.Windows.DependencyObject]
        $container = $null
        if ($null -ne $source) {
            $container = [System.Windows.Controls.ItemsControl]::ContainerFromElement($FolderList, $source)
        }
        if ($null -eq $container) {
            $script:CreateTextMenu.PlacementTarget = $FolderList
            $script:CreateTextMenu.IsOpen = $true
            $e.Handled = $true
        }
    } catch {
        # A click on a scrollbar or other chrome should simply do nothing.
    }
})

$PreviewImage.Add_MouseLeftButtonUp({
    param($sender, $e)
    if ($PreviewContentBorder.Visibility -ne 'Visible' -or $null -eq $PreviewImage.Source) { return }

    if ($script:PreviewZoomed) {
        $PreviewImage.RenderTransform = [System.Windows.Media.ScaleTransform]::new(1, 1)
        $script:PreviewZoomed = $false
        $StatusText.Text = 'Масштаб превʼю: стандартний'
    } else {
        $PreviewImage.RenderTransform = [System.Windows.Media.ScaleTransform]::new(2, 2)
        $script:PreviewZoomed = $true
        $StatusText.Text = 'Масштаб превʼю: 200% — натисніть ще раз, щоб повернути'
    }
    $e.Handled = $true
})

$BackButton.Add_Click({
    if ($script:History.Count -gt 0) {
        $lastIndex = $script:History.Count - 1
        $target = $script:History[$lastIndex]
        if (Navigate-To $target $false) {
            $script:History.RemoveAt($script:History.Count - 1)
            Update-NavigationButtons
            Save-Settings
        }
    }
})

$HomeButton.Add_Click({
    if ($script:RootFolder) { Navigate-To $script:RootFolder }
})

$UpButton.Add_Click({
    if (-not $script:CurrentFolder) { return }
    $parent = Split-Path -Parent $script:CurrentFolder
    if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
        Navigate-To $parent
    }
})

$PrevTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $script:TextIndex--
    if ($script:TextIndex -lt 0) { $script:TextIndex = $script:TextFiles.Count - 1 }
    Update-TextNavigation
})

$NextTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $script:TextIndex++
    if ($script:TextIndex -ge $script:TextFiles.Count) { $script:TextIndex = 0 }
    Update-TextNavigation
})

$window.Add_KeyDown({
    param($sender, $e)
    if (($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and $e.Key -eq [System.Windows.Input.Key]::S) {
        if ($script:TextDirty) { Save-CurrentTextFile | Out-Null }
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5 -and $script:CurrentFolder) {
        Navigate-To $script:CurrentFolder $false
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape -and $PreviewContentBorder.Visibility -eq 'Visible') {
        Show-TextMode
        $e.Handled = $true
    }
})

$BackButton.IsEnabled = $false
$UpButton.IsEnabled = $false
$HomeButton.IsEnabled = $false
$PrevTextButton.IsEnabled = $false
$NextTextButton.IsEnabled = $false
$TextViewer.Text = 'Оберіть кореневу папку, щоб почати.'
$TextCounter.Text = '0 / 0'

$window.Add_ContentRendered({
    if (Load-Settings) {
        $savedFolder = $script:CurrentFolder
        $script:CurrentFolder = $null
        Navigate-To $savedFolder $false
        Ensure-StartupNavigationHistory
        Save-Settings
    } else {
        Choose-RootFolder
    }
})

$window.Add_Closing({
    param($sender, $e)
    if (-not (Confirm-PendingTextChanges)) {
        $e.Cancel = $true
        return
    }
    Save-Settings
})
$window.Add_Closed({ Save-Settings })
$window.ShowDialog() | Out-Null
