using System.Diagnostics;
using System.Windows;

namespace SimpleAirPlay;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();
    }

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private void License_Click(object sender, RoutedEventArgs e)
    {
        OpenUrl("https://www.gnu.org/licenses/gpl-3.0.html");
    }

    private void GitHub_Click(object sender, RoutedEventArgs e)
    {
        OpenUrl("https://github.com/FDH2/UxPlay");
    }

    private static void OpenUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
        }
        catch { }
    }
}
