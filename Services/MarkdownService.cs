using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;

namespace VisualFolderExplorer.Services;

public static class MarkdownService
{
    public static FlowDocument Render(string markdown)
    {
        var document = new FlowDocument
        {
            PagePadding = new Thickness(14),
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 14,
            Foreground = new SolidColorBrush(Color.FromRgb(37, 42, 46))
        };

        var lines = Regex.Split(markdown ?? string.Empty, "\\r?\\n");
        var inCode = false;
        var code = new List<string>();

        foreach (var line in lines)
        {
            if (line.TrimStart().StartsWith("```"))
            {
                if (inCode)
                {
                    AddCode(document, code);
                    code.Clear();
                }
                inCode = !inCode;
                continue;
            }

            if (inCode)
            {
                code.Add(line);
                continue;
            }

            if (string.IsNullOrWhiteSpace(line))
            {
                document.Blocks.Add(new Paragraph { Margin = new Thickness(0, 0, 0, 5) });
                continue;
            }

            var heading = Regex.Match(line, "^(#{1,6})\\s+(.+)$");
            if (heading.Success)
            {
                var sizes = new[] { 28d, 24d, 21d, 18d, 16d, 14d };
                var p = new Paragraph { FontSize = sizes[heading.Groups[1].Value.Length - 1], FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 10, 0, 6) };
                AddInline(p, heading.Groups[2].Value);
                document.Blocks.Add(p);
                continue;
            }

            if (Regex.IsMatch(line, "^\\s*([-+*])\\s+"))
            {
                var p = new Paragraph { Margin = new Thickness(14, 2, 0, 2) };
                p.Inlines.Add(new Run("•  "));
                AddInline(p, Regex.Replace(line, "^\\s*[-+*]\\s+", string.Empty));
                document.Blocks.Add(p);
                continue;
            }

            var ordered = Regex.Match(line, "^\\s*(\\d+)\\.\\s+(.+)$");
            if (ordered.Success)
            {
                var p = new Paragraph { Margin = new Thickness(14, 2, 0, 2) };
                p.Inlines.Add(new Run(ordered.Groups[1].Value + ".  "));
                AddInline(p, ordered.Groups[2].Value);
                document.Blocks.Add(p);
                continue;
            }

            var quote = Regex.Match(line, "^\\s*>\\s?(.*)$");
            if (quote.Success)
            {
                var p = new Paragraph { Margin = new Thickness(8, 5, 0, 5), Padding = new Thickness(10, 6, 8, 6), Background = new SolidColorBrush(Color.FromRgb(243, 246, 248)) };
                AddInline(p, quote.Groups[1].Value);
                document.Blocks.Add(p);
                continue;
            }

            if (Regex.IsMatch(line, "^\\s*(---|___|\\*\\*\\*)\\s*$"))
            {
                document.Blocks.Add(new BlockUIContainer(new System.Windows.Controls.Border { Height = 1, Background = Brushes.LightGray, Margin = new Thickness(0, 9, 0, 9) }));
                continue;
            }

            var paragraph = new Paragraph { Margin = new Thickness(0, 2, 0, 6) };
            AddInline(paragraph, line);
            document.Blocks.Add(paragraph);
        }

        if (code.Count > 0) AddCode(document, code);
        return document;
    }

    private static void AddCode(FlowDocument document, IEnumerable<string> lines)
    {
        document.Blocks.Add(new Paragraph(new Run(string.Join(Environment.NewLine, lines)))
        {
            FontFamily = new FontFamily("Consolas"),
            Background = new SolidColorBrush(Color.FromRgb(240, 242, 244)),
            Padding = new Thickness(10),
            Margin = new Thickness(0, 6, 0, 10)
        });
    }

    private static void AddInline(Paragraph paragraph, string text)
    {
        var regex = new Regex("(\\*\\*[^*]+\\*\\*|`[^`]+`|\\*[^*]+\\*|\\[[^\\]]+\\]\\([^)]+\\))");
        var position = 0;
        foreach (Match match in regex.Matches(text))
        {
            if (match.Index > position) paragraph.Inlines.Add(new Run(text[position..match.Index]));
            var token = match.Value;
            if (token.StartsWith("**") && token.EndsWith("**")) paragraph.Inlines.Add(new Run(token[2..^2]) { FontWeight = FontWeights.SemiBold });
            else if (token.StartsWith('`') && token.EndsWith('`')) paragraph.Inlines.Add(new Run(token[1..^1]) { FontFamily = new FontFamily("Consolas"), Background = Brushes.Gainsboro });
            else if (token.StartsWith('*') && token.EndsWith('*')) paragraph.Inlines.Add(new Run(token[1..^1]) { FontStyle = FontStyles.Italic });
            else
            {
                var link = Regex.Match(token, "^\\[([^\\]]+)\\]\\(([^)]+)\\)$");
                paragraph.Inlines.Add(new Run(link.Success ? link.Groups[1].Value : token) { Foreground = Brushes.SteelBlue, TextDecorations = TextDecorations.Underline });
            }
            position = match.Index + match.Length;
        }
        if (position < text.Length) paragraph.Inlines.Add(new Run(text[position..]));
    }
}
