Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:RootFolder = $null
$script:CurrentFolder = $null
$script:TextFiles = @()
$script:TextIndex = -1
$script:ImageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff', '.webp')
$script:AppVersion = '0.1.0'
$script:SettingsFolder = Join-Path $env:LOCALAPPDATA 'VisualFolderExplorer'
$script:SettingsPath = Join-Path $script:SettingsFolder 'settings.json'

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Visual Folder Explorer v0.1.0" Height="820" Width="1420"
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
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="SidePanelTitle" Text="Текст" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23" VerticalAlignment="Center"/>
                        <TextBlock x:Name="TextFileName" Grid.Column="1" Margin="10,0,8,0" Foreground="#7A838B" FontSize="12" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" TextAlignment="Right"/>
                        <Button x:Name="ReturnToTextButton" Grid.Column="2" Content="До тексту" Style="{StaticResource ToolbarButton}" Margin="0" Padding="9,5" FontSize="12" Visibility="Collapsed" ToolTip="Повернутися до текстового опису"/>
                    </Grid>

                    <Grid Grid.Row="2">
                        <Border x:Name="TextContentBorder" BorderBrush="#E6EAED" BorderThickness="1" CornerRadius="8" Background="#FBFCFD">
                            <TextBox x:Name="TextViewer" BorderThickness="0" Background="Transparent" Padding="12" TextWrapping="Wrap"
                                     AcceptsReturn="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                                     IsReadOnly="True" FontSize="14" Foreground="#252A2E"/>
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

        if (-not [string]::IsNullOrWhiteSpace($savedCurrent) -and (Test-Path -LiteralPath $savedCurrent -PathType Container)) {
            $rootNormalized = [System.IO.Path]::GetFullPath($script:RootFolder).TrimEnd('\')
            $currentNormalized = [System.IO.Path]::GetFullPath($savedCurrent).TrimEnd('\')
            if ($currentNormalized.Equals($rootNormalized, [System.StringComparison]::OrdinalIgnoreCase) -or
                $currentNormalized.StartsWith($rootNormalized + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                $script:CurrentFolder = (Resolve-Path -LiteralPath $savedCurrent).Path
            }
        }

        if (-not $script:CurrentFolder) { $script:CurrentFolder = $script:RootFolder }
        return $true
    } catch {
        return $false
    }
}

function Show-TextMode {
    $TextContentBorder.Visibility = 'Visible'
    $PreviewContentBorder.Visibility = 'Collapsed'
    $TextNavigationPanel.Visibility = 'Visible'
    $ReturnToTextButton.Visibility = 'Collapsed'
    $SidePanelTitle.Text = 'Текст'
    $PreviewImage.Source = $null
    $PreviewError.Visibility = 'Collapsed'
    if ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0) {
        $TextFileName.Text = $script:TextFiles[$script:TextIndex].Name
    } else {
        $TextFileName.Text = ''
    }
}

function Update-TextNavigation {
    $count = $script:TextFiles.Count
    if ($count -eq 0) {
        $TextViewer.Text = 'У цій папці немає текстових файлів.'
        $TextFileName.Text = ''
        $TextCounter.Text = '0 / 0'
        $PrevTextButton.IsEnabled = $false
        $NextTextButton.IsEnabled = $false
        return
    }

    if ($script:TextIndex -lt 0) { $script:TextIndex = 0 }
    if ($script:TextIndex -ge $count) { $script:TextIndex = $count - 1 }

    $file = $script:TextFiles[$script:TextIndex]
    try {
        $TextViewer.Text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    } catch {
        try {
            $TextViewer.Text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        } catch {
            $TextViewer.Text = "Не вдалося прочитати файл.`r`n`r`n$($_.Exception.Message)"
        }
    }

    $TextFileName.Text = $file.Name
    $TextCounter.Text = "{0} / {1}" -f ($script:TextIndex + 1), $count
    $PrevTextButton.IsEnabled = ($count -gt 1)
    $NextTextButton.IsEnabled = ($count -gt 1)
}

function Load-TextFiles([string]$folder) {
    $script:TextFiles = @()
    $script:TextIndex = -1

    try {
        $files = @(Get-ChildItem -LiteralPath $folder -File -Filter '*.txt' -ErrorAction Stop)
        if ($files.Count -gt 0) {
            $folderName = Split-Path -Leaf $folder
            $preferred = "$folderName`_текст.txt"
            $script:TextFiles = @($files | Sort-Object @{ Expression = { if ($_.Name -ieq $preferred) { 0 } else { 1 } } }, @{ Expression = { Get-NaturalSortKey $_.Name } })
            $script:TextIndex = 0
        }
    } catch {
        $StatusText.Text = "Помилка читання текстових файлів: $($_.Exception.Message)"
    }

    Update-TextNavigation
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

    # Capture only UI references and the path. The preview is rendered directly in
    # the right panel, so the click handler does not depend on a helper function.
    $imagePath = $file.FullName
    $previewImageRef = $PreviewImage
    $previewErrorRef = $PreviewError
    $textContentRef = $TextContentBorder
    $previewContentRef = $PreviewContentBorder
    $textNavRef = $TextNavigationPanel
    $returnButtonRef = $ReturnToTextButton
    $sideTitleRef = $SidePanelTitle
    $fileNameRef = $TextFileName

    $clickHandler = {
        try {
            $bitmapPreview = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmapPreview.BeginInit()
            $bitmapPreview.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmapPreview.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
            $bitmapPreview.DecodePixelWidth = 1600
            $bitmapPreview.UriSource = New-Object System.Uri($imagePath, [System.UriKind]::Absolute)
            $bitmapPreview.EndInit()
            $bitmapPreview.Freeze()

            $previewImageRef.Source = $bitmapPreview
            $previewErrorRef.Visibility = 'Collapsed'
        } catch {
            $previewImageRef.Source = $null
            $previewErrorRef.Visibility = 'Visible'
        }

        $textContentRef.Visibility = 'Collapsed'
        $previewContentRef.Visibility = 'Visible'
        $textNavRef.Visibility = 'Collapsed'
        $returnButtonRef.Visibility = 'Visible'
        $sideTitleRef.Text = "Прев'ю"
        $fileNameRef.Text = [System.IO.Path]::GetFileName($imagePath)
    }.GetNewClosure()
    $tile.Add_MouseLeftButtonUp($clickHandler)

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
            $item.Tag = $dir.FullName
            $FolderList.Items.Add($item) | Out-Null
        }
    } catch {
        $StatusText.Text = "Помилка читання папок: $($_.Exception.Message)"
    }
}

function Navigate-To([string]$folder, [bool]$addHistory = $true) {
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) { return }

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

    $BackButton.IsEnabled = ($script:History.Count -gt 0)
    $HomeButton.IsEnabled = ($script:RootFolder -and ($script:CurrentFolder -ne $script:RootFolder))

    if ($script:RootFolder) {
        $currentNormalized = [System.IO.Path]::GetFullPath($script:CurrentFolder).TrimEnd('\')
        $rootNormalized = [System.IO.Path]::GetFullPath($script:RootFolder).TrimEnd('\')
        $UpButton.IsEnabled = ($currentNormalized -ne $rootNormalized -and $currentNormalized.StartsWith($rootNormalized, [System.StringComparison]::OrdinalIgnoreCase))
    } else {
        $UpButton.IsEnabled = $false
    }

    Save-Settings
}

function Choose-RootFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Оберіть кореневу папку з вашими матеріалами'
    $dialog.ShowNewFolderButton = $true
    if ($script:RootFolder -and (Test-Path -LiteralPath $script:RootFolder)) {
        $dialog.SelectedPath = $script:RootFolder
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:RootFolder = $dialog.SelectedPath
        $script:History.Clear()
        Navigate-To $script:RootFolder $false
    }
}

$ChooseRootButton.Add_Click({ Choose-RootFolder })
$ReturnToTextButton.Add_Click({ Show-TextMode })

$FolderList.Add_MouseDoubleClick({
    if ($FolderList.SelectedItem -and $FolderList.SelectedItem.Tag) {
        Navigate-To ([string]$FolderList.SelectedItem.Tag)
    }
})

$BackButton.Add_Click({
    if ($script:History.Count -gt 0) {
        $lastIndex = $script:History.Count - 1
        $target = $script:History[$lastIndex]
        $script:History.RemoveAt($lastIndex)
        Navigate-To $target $false
        $BackButton.IsEnabled = ($script:History.Count -gt 0)
    }
})

$HomeButton.Add_Click({
    if ($script:RootFolder) { Navigate-To $script:RootFolder }
})

$UpButton.Add_Click({
    if (-not $script:CurrentFolder -or -not $script:RootFolder) { return }
    $parent = Split-Path -Parent $script:CurrentFolder
    if (-not $parent) { return }

    $rootNormalized = [System.IO.Path]::GetFullPath($script:RootFolder).TrimEnd('\')
    $parentNormalized = [System.IO.Path]::GetFullPath($parent).TrimEnd('\')
    if ($parentNormalized.StartsWith($rootNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
        Navigate-To $parent
    }
})

$PrevTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    $script:TextIndex--
    if ($script:TextIndex -lt 0) { $script:TextIndex = $script:TextFiles.Count - 1 }
    Update-TextNavigation
})

$NextTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    $script:TextIndex++
    if ($script:TextIndex -ge $script:TextFiles.Count) { $script:TextIndex = 0 }
    Update-TextNavigation
})

$window.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::F5 -and $script:CurrentFolder) {
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
    } else {
        Choose-RootFolder
    }
})

$window.Add_Closed({ Save-Settings })
$window.ShowDialog() | Out-Null
