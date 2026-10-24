using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class PresentationContractTests
{
    [TestMethod]
    public void StatusOverlayIsNonactivatingAndNeverDisplaysTranscriptText()
    {
        var xaml = Read("Windows/Resenha.Windows/StatusWindow.xaml");
        var code = Read("Windows/Resenha.Windows/StatusWindow.xaml.cs");
        StringAssert.Contains(xaml, "ShowActivated=\"False\"");
        StringAssert.Contains(xaml, "ShowInTaskbar=\"False\"");
        StringAssert.Contains(code, "NoActivate");
        Assert.IsFalse(xaml.Contains("LastResult", StringComparison.Ordinal));
    }

    [TestMethod]
    public void ManifestAndSettingsStayNormalUserAndLocalOnly()
    {
        var manifest = Read("Windows/Resenha.Windows/app.manifest");
        var settings = Read("Windows/Resenha.Windows/SettingsWindow.xaml");
        StringAssert.Contains(manifest, "level=\"asInvoker\" uiAccess=\"false\"");
        StringAssert.Contains(settings, "Local, gratuito e sem conta");
        StringAssert.Contains(settings, "SelectedShortcut");
        StringAssert.Contains(settings, "SelectedMicrophone");
        StringAssert.Contains(settings, "VerticalScrollBarVisibility=\"Auto\"");
        StringAssert.Contains(settings, "MicrophoneNotice");
        var app = Read("Windows/Resenha.Windows/App.xaml.cs");
        StringAssert.Contains(app, "recorder.EnumerateAsync");
        StringAssert.Contains(app, "model.RefreshMicrophonesAsync");
        StringAssert.Contains(settings, "RefreshMicrophones_Click");
        Assert.IsFalse(settings.Contains("histórico", StringComparison.OrdinalIgnoreCase));
    }

    [TestMethod]
    public void TrayExposesOnlyBoundedRecoveryAndLifecycleCommands()
    {
        var tray = Read("Windows/Resenha.Windows/TrayController.cs");
        foreach (var command in new[] { "Abrir ajustes", "Cancelar ditado", "Copiar último texto", "Sair do Resenha" })
        { StringAssert.Contains(tray, command); }
        Assert.IsFalse(tray.Contains("history", StringComparison.OrdinalIgnoreCase));
    }

    private static string Read(string relative)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, relative.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(candidate)) { return File.ReadAllText(candidate); }
            directory = directory.Parent;
        }
        Assert.Fail($"Repository file not found: {relative}");
        return string.Empty;
    }
}
