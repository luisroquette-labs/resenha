using System.Drawing;
using Forms = System.Windows.Forms;

namespace Resenha.Windows;

public sealed class TrayController : IDisposable
{
    private readonly Forms.NotifyIcon icon;
    public TrayController()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Abrir ajustes", null, (_, _) => OpenSettings?.Invoke());
        menu.Items.Add("Cancelar ditado", null, (_, _) => Cancel?.Invoke());
        menu.Items.Add("Copiar último texto", null, (_, _) => CopyLast?.Invoke());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Sair do Resenha", null, (_, _) => Exit?.Invoke());
        icon = new()
        {
            Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? SystemIcons.Application,
            Text = "Resenha — pronto para ouvir",
            ContextMenuStrip = menu,
            Visible = true
        };
        icon.DoubleClick += (_, _) => OpenSettings?.Invoke();
    }

    public event Action? OpenSettings;
    public event Action? Cancel;
    public event Action? CopyLast;
    public event Action? Exit;
    public void SetStatus(string text) => icon.Text = text.Length <= 63 ? text : text[..63];
    public void Dispose() { icon.Visible = false; icon.Dispose(); }
}
