using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace Resenha.Windows;

public partial class StatusWindow : Window
{
    private const int ExtendedStyle = -20;
    private const nint NoActivate = 0x08000000;

    public StatusWindow(ProductViewModel model)
    {
        InitializeComponent();
        DataContext = model;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        var handle = new WindowInteropHelper(this).Handle;
        Native.SetWindowLongPtrW(handle, ExtendedStyle,
            Native.GetWindowLongPtrW(handle, ExtendedStyle) | NoActivate);
        Position();
    }

    private void Position()
    {
        var area = SystemParameters.WorkArea;
        Left = area.Left + (area.Width - Width) / 2;
        Top = area.Bottom - Height - 34;
    }

    private static class Native
    {
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetWindowLongPtrW(nint window, int index);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint SetWindowLongPtrW(nint window, int index, nint value);
    }
}
