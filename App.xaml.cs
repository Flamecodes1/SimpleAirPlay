using System.Windows;

namespace SimpleAirPlay;

/// <summary>
/// Application entry point for Simple AirPlay 5.0
/// </summary>
public partial class App : Application
{
    private static System.Threading.Mutex? _mutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Ensure only one instance runs at a time
        _mutex = new System.Threading.Mutex(true, "SimpleAirPlay_SingleInstance", out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("Simple AirPlay läuft bereits!", "Simple AirPlay",
                MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }
    }
}
