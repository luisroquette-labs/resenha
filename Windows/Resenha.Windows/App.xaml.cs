using System.Windows;

namespace Resenha.Windows;

// Step 12 owns runtime composition. This scaffold installs no hooks, opens no
// microphone, starts no process/network operation and does not alter clipboard.
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Shutdown(0);
    }
}
