using System.Windows;

namespace Resenha.Windows;

public partial class FirstRunWindow : Window
{
    public FirstRunWindow() => InitializeComponent();
    private void Continue_Click(object sender, RoutedEventArgs e) => Close();
}
