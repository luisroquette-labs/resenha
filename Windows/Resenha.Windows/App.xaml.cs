using System.ComponentModel;
using System.IO;
using System.IO.Pipes;
using System.Security.Principal;
using System.Windows;
using Resenha.Core;
using Resenha.Platform;

namespace Resenha.Windows;

public partial class App : System.Windows.Application
{
    private SingleInstanceCoordinator? singleInstance;
    private KeyboardHook? shortcut;
    private DictationCoordinator? coordinator;
    private ProductViewModel? model;
    private TrayController? tray;
    private SettingsWindow? settings;
    private StatusWindow? status;
    private bool shuttingDown;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        singleInstance = new SingleInstanceCoordinator();
        if (!singleInstance.IsPrimary)
        {
            await singleInstance.SignalPrimaryAsync();
            Shutdown(0);
            return;
        }
        singleInstance.ShowSettingsRequested += () => Dispatcher.BeginInvoke(OpenSettingsIfIdle);

        var localData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var appData = Path.Combine(localData, "Resenha");
        var readiness = PlatformReadiness.Evaluate(appData);
        if (!readiness.IsReady)
        {
            System.Windows.MessageBox.Show(ReadinessMessage(readiness), "Resenha não pode iniciar",
                MessageBoxButton.OK, MessageBoxImage.Warning);
            await ShutdownAsync(2);
            return;
        }

        try
        {
            var clock = new MonotonicClock();
            var activity = new TargetActivityTracker();
            shortcut = new(clock, activity);
            var sessions = new SessionFiles(appData);
            sessions.CleanupOrphans();
            var recorder = new WasapiRecorder(sessions, clock);
            var models = new ModelStore(appData);
            var target = new TargetBrokerClient(AppContext.BaseDirectory, activity, clock);
            var clipboard = new ClipboardService();
            var injector = new TextInjector(target, clipboard, clock);
            var transcriber = new WhisperCliTranscriber(AppContext.BaseDirectory, clock);
            coordinator = new(clock, recorder, models, transcriber, target, clipboard, injector, shortcut);

            var preferenceStore = new PreferencesStore(localData);
            var microphones = await recorder.EnumerateAsync(AttemptId.New(), default);
            var available = microphones.IsSuccess ? microphones.Value! : [];
            var loaded = await preferenceStore.LoadAsync(AttemptId.New(), default);
            var firstRun = !loaded.IsSuccess;
            var initial = loaded.IsSuccess ? loaded.Value! : new ProductPreferences(1,
                ShortcutPolicy.Default, available.FirstOrDefault(item => item.IsDefault)?.Id
                    ?? available.FirstOrDefault()?.Id ?? string.Empty, DictationLanguage.Pt);
            model = new(coordinator, preferenceStore, models, initial, available,
                recorder.EnumerateAsync, ApplyPreferencesAsync);
            settings = new(model);
            settings.Closing += SettingsClosing;
            status = new(model);
            tray = new();
            tray.OpenSettings += OpenSettings;
            tray.Cancel += () => _ = model.CancelOrAcknowledgeAsync();
            tray.CopyLast += () => _ = CopyLastAsync();
            tray.Exit += () => _ = ShutdownAsync(0);
            coordinator.StatusChanged += OnStatusChanged;
            shortcut.Edge += ShortcutEdge;

            if (PreferencesStore.IsValid(initial))
            {
                var applied = await ApplyPreferencesAsync(initial, default);
                if (!applied.IsSuccess) { firstRun = true; }
            }
            if (firstRun) { OpenSettings(); }
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException
            or InvalidOperationException or PlatformNotSupportedException)
        {
            System.Windows.MessageBox.Show("O Resenha não conseguiu preparar os recursos locais. Feche e abra o aplicativo.",
                "Falha ao iniciar", MessageBoxButton.OK, MessageBoxImage.Error);
            await ShutdownAsync(2);
        }
    }

    private async ValueTask<Outcome<Unit>> ApplyPreferencesAsync(ProductPreferences preferences,
        CancellationToken cancellationToken)
    {
        var operation = AttemptId.New();
        var activeShortcut = shortcut;
        var activeCoordinator = coordinator;
        if (activeShortcut is null || activeCoordinator is null || !PreferencesStore.IsValid(preferences))
        { return Outcome<Unit>.Failed(operation, ErrorCode.NotReady); }
        await activeCoordinator.CancelAsync(cancellationToken);
        var configured = await activeShortcut.ConfigureAsync(operation, preferences.Shortcut, cancellationToken);
        if (!configured.IsSuccess) { return configured; }
        return settings?.IsVisible == true
            ? Outcome<Unit>.Success(operation, default)
            : await activeShortcut.StartAsync(operation, cancellationToken);
    }

    private void OnStatusChanged(DictationStatus value) => Dispatcher.BeginInvoke(() =>
    {
        if (status is null || tray is null) { return; }
        tray.SetStatus(value.State switch
        {
            DictationState.Recording => "Resenha — ouvindo",
            DictationState.Transcribing => "Resenha — transcrevendo",
            DictationState.Inserting => "Resenha — inserindo",
            DictationState.Failed => "Resenha — atenção necessária",
            _ => "Resenha — pronto para ouvir"
        });
        if (value.State == DictationState.Idle) { status.Hide(); }
        else if (!status.IsVisible) { status.Show(); }
        if (value.IsFatal) { _ = ShutdownAfterFatalAsync(); }
    });

    private async Task ShutdownAfterFatalAsync()
    {
        await Task.Delay(TimeSpan.FromSeconds(3));
        await ShutdownAsync(3);
    }

    private void OpenSettings()
    {
        if (settings is null || coordinator is null) { return; }
        _ = OpenSettingsAsync();
    }

    private void OpenSettingsIfIdle()
    {
        if (coordinator?.Status.State == DictationState.Idle) { OpenSettings(); }
    }

    private async Task OpenSettingsAsync()
    {
        await coordinator!.CancelAsync();
        if (shortcut is not null) { await shortcut.StopAsync(AttemptId.New(), default); }
        if (model is not null) { await model.RefreshMicrophonesAsync(); }
        settings!.Show();
        settings.WindowState = WindowState.Normal;
        settings.Activate();
    }

    private void SettingsClosing(object? sender, CancelEventArgs e)
    {
        if (shuttingDown) { return; }
        e.Cancel = true;
        settings?.Hide();
        _ = ResumeShortcutAsync();
    }

    private async Task ResumeShortcutAsync()
    {
        if (shortcut is null || model is null || shuttingDown) { return; }
        var operation = AttemptId.New();
        var configured = await shortcut.ConfigureAsync(operation, model.Preferences.Shortcut, default);
        if (configured.IsSuccess) { await shortcut.StartAsync(operation, default); }
    }

    private async Task CopyLastAsync()
    {
        if (coordinator is not null) { await coordinator.CopyLastAsync(); }
    }

    private async Task HandleEdgeAsync(ShortcutEdge edge)
    {
        if (coordinator is not null && model is not null)
        { await coordinator.HandleShortcutAsync(edge, model.Preferences); }
    }

    private async Task ShutdownAsync(int code)
    {
        if (shuttingDown) { return; }
        shuttingDown = true;
        if (shortcut is not null) { shortcut.Edge -= ShortcutEdge; }
        if (coordinator is not null)
        {
            coordinator.StatusChanged -= OnStatusChanged;
            await coordinator.DisposeAsync();
        }
        if (shortcut is not null) { await shortcut.DisposeAsync(); }
        if (model is not null) { await model.ClearLastResultAsync(); }
        model?.Dispose();
        tray?.Dispose();
        status?.Close();
        settings?.Close();
        singleInstance?.Dispose();
        Shutdown(code);
    }

    private void ShortcutEdge(ShortcutEdge edge) => _ = HandleEdgeAsync(edge);

    private static string ReadinessMessage(ReadinessReport report) => report.Failures.FirstOrDefault() switch
    {
        ErrorCode.UnsupportedPlatform => "Use Windows 10 22H2 ou Windows 11 em um computador x64 compatível.",
        ErrorCode.UnsupportedCpu => "Este computador não oferece as instruções de CPU exigidas pelo modelo local.",
        ErrorCode.MediaFoundationUnavailable => "Instale o Media Feature Pack nas Configurações do Windows.",
        ErrorCode.StorageUnsafe => "Libere pelo menos 1 GB no disco do aplicativo.",
        _ => "O Resenha requer 8 GB de memória disponível para iniciar com segurança."
    };
}

internal sealed class SingleInstanceCoordinator : IDisposable
{
    private readonly Mutex mutex;
    private readonly string pipeName;
    private readonly CancellationTokenSource stop = new();
    private readonly Task listener;

    internal SingleInstanceCoordinator()
    {
        var identity = WindowsIdentity.GetCurrent().User?.Value ?? Environment.UserName;
        var suffix = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(identity)))[..16];
        pipeName = "Resenha-" + suffix;
        mutex = new(false, "Local\\Resenha-" + suffix, out var created);
        IsPrimary = created;
        listener = created ? Task.Run(ListenAsync) : Task.CompletedTask;
    }

    internal bool IsPrimary { get; }
    internal event Action? ShowSettingsRequested;

    internal async Task SignalPrimaryAsync()
    {
        try
        {
            await using var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.Out,
                PipeOptions.Asynchronous, TokenImpersonationLevel.Identification);
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(1));
            await pipe.ConnectAsync(timeout.Token);
            await pipe.WriteAsync(new byte[] { 1 }, timeout.Token);
        }
        catch (Exception error) when (error is IOException or OperationCanceledException) { }
    }

    private async Task ListenAsync()
    {
        while (!stop.IsCancellationRequested)
        {
            try
            {
                await using var pipe = new NamedPipeServerStream(pipeName, PipeDirection.In, 1,
                    PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                await pipe.WaitForConnectionAsync(stop.Token);
                var message = new byte[1];
                if (await pipe.ReadAsync(message, stop.Token) == 1 && message[0] == 1)
                { ShowSettingsRequested?.Invoke(); }
            }
            catch (OperationCanceledException) { break; }
            catch (IOException) { }
        }
    }

    public void Dispose()
    {
        stop.Cancel();
        try { listener.Wait(TimeSpan.FromSeconds(1)); } catch (AggregateException) { }
        stop.Dispose();
        mutex.Dispose();
    }
}
