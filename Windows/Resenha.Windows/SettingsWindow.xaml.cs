using System.Windows;
using System.Windows.Input;
using System.Runtime.InteropServices;
using Resenha.Core;

namespace Resenha.Windows;

public partial class SettingsWindow : Window
{
    private readonly ProductViewModel model;
    private bool capturing;
    public SettingsWindow(ProductViewModel model)
    {
        InitializeComponent();
        this.model = model;
        DataContext = model;
        PreviewKeyDown += CaptureKeyDown;
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        if ((await model.SaveAsync()).IsSuccess) { Close(); }
    }
    private async void Download_Click(object sender, RoutedEventArgs e) => await model.DownloadModelAsync();
    private async void RefreshMicrophones_Click(object sender, RoutedEventArgs e) => await model.RefreshMicrophonesAsync();
    private async void Clear_Click(object sender, RoutedEventArgs e) => await model.ClearLastResultAsync();

    private void Capture_Click(object sender, RoutedEventArgs e)
    {
        capturing = true;
        CaptureButton.Content = "Pressione a combinação…";
        Keyboard.Focus(CaptureButton);
    }

    private void CaptureKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (!capturing) { return; }
        e.Handled = true;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        if (key == Key.Escape) { FinishCapture(); return; }
        var virtualKey = KeyInterop.VirtualKeyFromKey(key);
        if (virtualKey is 0x10 or 0x11 or 0x12 or 0x5b or 0x5c) { return; }
        var modifiers = ReadModifiers();
        var encoded = Native.MapVirtualKeyW((uint)virtualKey, 4);
        var shortcut = new Resenha.Core.Shortcut((ushort)(encoded & 0xff),
            (encoded & 0xff00) is 0xe000 or 0xe100, modifiers);
        model.TrySetShortcut(shortcut);
        FinishCapture();
    }

    private void FinishCapture()
    {
        capturing = false;
        CaptureButton.Content = "Gravar atalho";
    }

    private static ShortcutModifiers ReadModifiers()
    {
        var value = ShortcutModifiers.None;
        if (Native.GetAsyncKeyState(0xa2) < 0) { value |= ShortcutModifiers.LeftControl; }
        if (Native.GetAsyncKeyState(0xa3) < 0) { value |= ShortcutModifiers.RightControl; }
        if (Native.GetAsyncKeyState(0xa4) < 0) { value |= ShortcutModifiers.LeftAlt; }
        if (Native.GetAsyncKeyState(0xa5) < 0) { value |= ShortcutModifiers.RightAlt; }
        if (Native.GetAsyncKeyState(0xa0) < 0) { value |= ShortcutModifiers.LeftShift; }
        if (Native.GetAsyncKeyState(0xa1) < 0) { value |= ShortcutModifiers.RightShift; }
        if (Native.GetAsyncKeyState(0x5b) < 0) { value |= ShortcutModifiers.LeftWindows; }
        if (Native.GetAsyncKeyState(0x5c) < 0) { value |= ShortcutModifiers.RightWindows; }
        return value;
    }

    private static class Native
    {
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern uint MapVirtualKeyW(uint code, uint mapType);
    }
}
