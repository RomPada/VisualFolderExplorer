using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class SimilarityGroupsWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly ThumbnailService _thumbnailService = new();
    private readonly IReadOnlyList<string> _paths;
    private readonly string _folder;
    private readonly List<SimilarityHashResult> _hashes = [];
    private readonly List<SimilarityGroup> _groups = [];
    private CancellationTokenSource? _analysisCts;
    private CancellationTokenSource? _thumbnailCts;
    private bool _analysisComplete;
    private bool _initializing = true;
    private bool _thresholdCommitPending;

    public bool AppliedChanges { get; private set; }
    public int CreatedFolderCount { get; private set; }
    public int MovedFileCount { get; private set; }
    public double Threshold => ThresholdSlider.Value;

    public SimilarityGroupsWindow(LocalizationService loc, IReadOnlyList<string> paths, string folder, double initialThreshold)
    {
        InitializeComponent();
        _loc = loc;
        _paths = paths.Where(File.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        _folder = folder;
        ThresholdSlider.Value = Math.Clamp(initialThreshold, ThresholdSlider.Minimum, ThresholdSlider.Maximum);
        ThresholdSlider.AddHandler(Thumb.DragCompletedEvent, new DragCompletedEventHandler(ThresholdSlider_DragCompleted));
        ApplyLanguage();
        _initializing = false;
        UpdateThresholdLabel();
    }

    private void ApplyLanguage()
    {
        Title = _loc.T("SimilarityTitle");
        TitleText.Text = _loc.T("SimilarityTitle");
        IntroText.Text = _loc.T("SimilarityIntro");
        LocalBadgeText.Text = _loc.T("SimilarityLocalBadge");
        ThresholdLabel.Text = _loc.T("SimilarityThreshold");
        ThresholdHintText.Text = _loc.T("SimilarityThresholdHint");
        PrefixLabel.Text = _loc.T("SimilarityFolderPrefix");
        ReanalyzeButton.Content = _loc.T("SimilarityReanalyze");
        CloseButton.Content = _loc.T("Close");
        ApplyButton.Content = _loc.T("SimilarityApply");
        EmptyTitleText.Text = _loc.T("SimilarityNoGroups");
        EmptyHintText.Text = _loc.T("SimilarityNoGroupsHint");
        BottomHintText.Text = _loc.T("SimilarityBottomHint");
        UpdateThresholdLabel();
        UpdateGroupSummary();
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e) => await AnalyzeAsync();

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        _analysisCts?.Cancel();
        _thumbnailCts?.Cancel();
    }

    private async Task AnalyzeAsync()
    {
        _analysisCts?.Cancel();
        _analysisCts?.Dispose();
        _analysisCts = new CancellationTokenSource();
        _hashes.Clear();
        _groups.Clear();
        _analysisComplete = false;
        GroupsList.ItemsSource = null;
        EmptyPanel.Visibility = Visibility.Collapsed;
        ApplyButton.IsEnabled = false;
        ReanalyzeButton.IsEnabled = false;
        AnalysisProgress.Value = 0;
        StatusText.Text = _loc.T("SimilarityAnalyzing", 0, _paths.Count, 0);

        if (_paths.Count < 2)
        {
            _analysisComplete = true;
            ShowEmptyState();
            ReanalyzeButton.IsEnabled = true;
            return;
        }

        try
        {
            var progress = new Progress<(int Done, int Total, int Failed)>(p =>
            {
                AnalysisProgress.Value = p.Total == 0 ? 0 : 100.0 * p.Done / p.Total;
                StatusText.Text = _loc.T("SimilarityAnalyzing", p.Done, p.Total, p.Failed);
            });
            var results = await SimilarityService.AnalyzeAsync(_paths, progress, _analysisCts.Token);
            _hashes.AddRange(results);
            _analysisComplete = true;
            AnalysisProgress.Value = 100;
            Regroup();
            await LoadVisibleThumbnailsAsync();
        }
        catch (OperationCanceledException)
        {
            StatusText.Text = _loc.T("SimilarityCancelled");
        }
        catch (Exception ex)
        {
            var notice = new NoticeWindow(_loc.T("Error"), ex.Message, "OK", NoticeKind.Error) { Owner = this };
            notice.ShowDialog();
        }
        finally
        {
            ReanalyzeButton.IsEnabled = true;
        }
    }

    private void Regroup()
    {
        if (!_analysisComplete) return;
        foreach (var group in _groups)
            foreach (var item in group.Images)
                item.PropertyChanged -= SimilarityItem_PropertyChanged;
        _groups.Clear();
        _groups.AddRange(SimilarityService.Group(_hashes, ThresholdSlider.Value));
        foreach (var group in _groups)
        {
            group.Title = $"{_loc.T("SimilarityGroup")} {group.GroupNumber:000}";
            foreach (var item in group.Images)
                item.PropertyChanged += SimilarityItem_PropertyChanged;
        }
        GroupsList.ItemsSource = null;
        GroupsList.ItemsSource = _groups;
        if (_groups.Count == 0) ShowEmptyState();
        else
        {
            EmptyPanel.Visibility = Visibility.Collapsed;
            GroupsList.Visibility = Visibility.Visible;
            StatusText.Text = _loc.T("SimilarityReady", _hashes.Count, _groups.Count);
        }
        UpdateGroupSummary();
        UpdateApplyState();
    }

    private void ShowEmptyState()
    {
        GroupsList.Visibility = Visibility.Collapsed;
        EmptyPanel.Visibility = Visibility.Visible;
        StatusText.Text = _loc.T("SimilarityNoGroups");
        UpdateGroupSummary();
        UpdateApplyState();
    }

    private async Task LoadVisibleThumbnailsAsync()
    {
        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = new CancellationTokenSource();
        var token = _thumbnailCts.Token;
        var items = _groups.SelectMany(g => g.Images).ToList();
        using var semaphore = new SemaphoreSlim(5);
        try
        {
            var tasks = items.Select(async item =>
            {
                await semaphore.WaitAsync(token);
                try
                {
                    var thumb = await _thumbnailService.GetThumbnailAsync(item.FullPath, 160, token);
                    if (!token.IsCancellationRequested && thumb is not null) item.Thumbnail = thumb;
                }
                finally { semaphore.Release(); }
            });
            await Task.WhenAll(tasks);
        }
        catch (OperationCanceledException) { }
    }

    private void ThresholdSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        // While the thumb is moving we only update the percentage label.
        // Rebuilding groups can be expensive for hundreds/thousands of images,
        // so the actual regroup happens only after the user releases the slider.
        UpdateThresholdLabel();
        if (_initializing || !_analysisComplete) return;
        _thresholdCommitPending = true;
    }

    private async void ThresholdSlider_DragCompleted(object sender, DragCompletedEventArgs e) => await CommitThresholdChangeAsync();

    private async void ThresholdSlider_PreviewMouseLeftButtonUp(object sender, MouseButtonEventArgs e) => await CommitThresholdChangeAsync();

    private async void ThresholdSlider_PreviewKeyUp(object sender, KeyEventArgs e)
    {
        if (e.Key is Key.Left or Key.Right or Key.Up or Key.Down or Key.PageUp or Key.PageDown or Key.Home or Key.End)
            await CommitThresholdChangeAsync();
    }

    private async Task CommitThresholdChangeAsync()
    {
        if (!_thresholdCommitPending || !_analysisComplete) return;
        _thresholdCommitPending = false;
        Regroup();
        await LoadVisibleThumbnailsAsync();
    }

    private void UpdateThresholdLabel()
    {
        if (ThresholdValueText is not null) ThresholdValueText.Text = $"{ThresholdSlider.Value:0}%";
    }

    private void ImageIncludeCheckBox_Click(object sender, RoutedEventArgs e)
    {
        UpdateGroupSummary();
        UpdateApplyState();
    }

    private void SimilarityItem_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(SimilarityItem.IsIncluded))
        {
            UpdateGroupSummary();
            UpdateApplyState();
        }
    }

    private void UpdateGroupSummary()
    {
        if (GroupSummaryText is null) return;
        var activeGroups = _groups.Count(g => g.Images.Count(i => i.IsIncluded) >= 2);
        var files = _groups.Where(g => g.Images.Count(i => i.IsIncluded) >= 2).Sum(g => g.Images.Count(i => i.IsIncluded));
        GroupSummaryText.Text = _loc.T("SimilaritySummary", activeGroups, files);
    }

    private void UpdateApplyState()
    {
        if (ApplyButton is null) return;
        ApplyButton.IsEnabled = _analysisComplete && _groups.Any(g => g.Images.Count(i => i.IsIncluded) >= 2);
    }

    private async void ReanalyzeButton_Click(object sender, RoutedEventArgs e) => await AnalyzeAsync();

    private async void ApplyButton_Click(object sender, RoutedEventArgs e)
    {
        var activeGroups = _groups.Where(g => g.Images.Count(i => i.IsIncluded) >= 2).ToList();
        if (activeGroups.Count == 0) return;
        var prefix = SanitizeFolderPrefix(PrefixBox.Text);
        if (string.IsNullOrWhiteSpace(prefix)) prefix = "Similar";
        var totalFiles = activeGroups.Sum(g => g.Images.Count(i => i.IsIncluded));

        var confirm = new ConfirmWindow(
            _loc.T("SimilarityTitle"),
            _loc.T("SimilarityApplyQuestion", activeGroups.Count, totalFiles, prefix),
            _loc.T("Yes"), string.Empty, _loc.T("No"), false) { Owner = this };
        confirm.ShowDialog();
        if (confirm.Choice != ConfirmChoice.Primary) return;

        ApplyButton.IsEnabled = false;
        ReanalyzeButton.IsEnabled = false;
        ThresholdSlider.IsEnabled = false;
        PrefixBox.IsEnabled = false;
        try
        {
            var nextFolderNumber = 1;
            var created = 0;
            var moved = 0;
            foreach (var group in activeGroups)
            {
                var folderName = GetNextFolderName(prefix, ref nextFolderNumber);
                var destination = Path.Combine(_folder, folderName);
                Directory.CreateDirectory(destination);
                var files = group.Images.Where(i => i.IsIncluded && File.Exists(i.FullPath)).Select(i => i.FullPath).ToList();
                if (files.Count < 2)
                {
                    if (!Directory.EnumerateFileSystemEntries(destination).Any()) Directory.Delete(destination);
                    continue;
                }
                var plan = FileService.BuildMovePlan(files, destination);
                await FileService.ExecuteMovePlanAsync(plan);
                moved += plan.Count;
                created++;
                StatusText.Text = _loc.T("SimilarityMoving", moved, totalFiles);
            }

            AppliedChanges = created > 0;
            CreatedFolderCount = created;
            MovedFileCount = moved;
            DialogResult = true;
        }
        catch (Exception ex)
        {
            var notice = new NoticeWindow(_loc.T("Error"), ex.Message, "OK", NoticeKind.Error) { Owner = this };
            notice.ShowDialog();
            ApplyButton.IsEnabled = true;
            ReanalyzeButton.IsEnabled = true;
            ThresholdSlider.IsEnabled = true;
            PrefixBox.IsEnabled = true;
        }
    }

    private string GetNextFolderName(string prefix, ref int number)
    {
        while (true)
        {
            var name = $"{prefix}_{number:000}";
            number++;
            var path = Path.Combine(_folder, name);
            if (!Directory.Exists(path) && !File.Exists(path)) return name;
        }
    }

    private static string SanitizeFolderPrefix(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var cleaned = new string((value ?? string.Empty).Trim().Where(ch => !invalid.Contains(ch)).ToArray());
        return cleaned.Trim().TrimEnd('.');
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
