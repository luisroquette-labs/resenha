using System.ComponentModel;
using System.Runtime.CompilerServices;
using Resenha.Core;
using Resenha.Platform;

namespace Resenha.Windows;

public sealed class ProductViewModel : INotifyPropertyChanged, IDisposable
{
    private readonly DictationCoordinator coordinator;
    private readonly PreferencesStore preferences;
    private readonly ModelStore models;
    private readonly Func<AttemptId, CancellationToken,
        ValueTask<Outcome<IReadOnlyList<MicrophoneEndpoint>>>> enumerateMicrophones;
    private readonly Func<ProductPreferences, CancellationToken, ValueTask<Outcome<Unit>>> applyPreferences;
    private readonly SynchronizationContext ui;
    private ProductPreferences value;
    private string notice = "Pronto para ouvir";
    private bool disposed;

    public ProductViewModel(DictationCoordinator coordinator, PreferencesStore preferences, ModelStore models,
        ProductPreferences initial, IReadOnlyList<MicrophoneEndpoint> microphones,
        Func<AttemptId, CancellationToken,
            ValueTask<Outcome<IReadOnlyList<MicrophoneEndpoint>>>> enumerateMicrophones,
        Func<ProductPreferences, CancellationToken, ValueTask<Outcome<Unit>>> applyPreferences,
        SynchronizationContext? ui = null)
    {
        this.coordinator = coordinator;
        this.preferences = preferences;
        this.models = models;
        this.enumerateMicrophones = enumerateMicrophones;
        this.applyPreferences = applyPreferences;
        value = initial;
        Microphones = microphones;
        if (ShortcutChoices.All(choice => choice.Shortcut != initial.Shortcut))
        { ShortcutChoices.Add(new("Atalho personalizado", initial.Shortcut)); }
        this.ui = ui ?? SynchronizationContext.Current ?? new SynchronizationContext();
        coordinator.StatusChanged += OnStatusChanged;
        Apply(coordinator.Status);
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public ProductPreferences Preferences => value;
    public Array Languages => Enum.GetValues<DictationLanguage>();
    public IReadOnlyList<MicrophoneEndpoint> Microphones { get; private set; }
    public string MicrophoneNotice => Microphones.Count == 0
        ? "Nenhum microfone encontrado. Conecte um dispositivo para ditar."
        : string.Empty;
    public List<ShortcutChoice> ShortcutChoices { get; } =
    [
        new("Ctrl esquerdo + Alt esquerdo + Espaço", ShortcutPolicy.Default),
        new("Ctrl esquerdo + Shift esquerdo + Espaço", new(0x39, false, ShortcutModifiers.LeftControl | ShortcutModifiers.LeftShift)),
        new("Alt esquerdo + Shift esquerdo + Espaço", new(0x39, false, ShortcutModifiers.LeftAlt | ShortcutModifiers.LeftShift)),
        new("Ctrl esquerdo + Alt esquerdo + R", new(0x13, false, ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt))
    ];
    public DictationLanguage Language
    {
        get => value.Language;
        set { if (this.value.Language != value) { this.value = this.value with { Language = value }; Changed(); } }
    }
    public MicrophoneEndpoint? SelectedMicrophone
    {
        get => Microphones.FirstOrDefault(item => item.Id == value.MicrophoneEndpointId);
        set
        {
            if (value is not null && this.value.MicrophoneEndpointId != value.Id)
            { this.value = this.value with { MicrophoneEndpointId = value.Id }; Changed(); }
        }
    }
    public ShortcutChoice SelectedShortcut
    {
        get => ShortcutChoices.FirstOrDefault(choice => choice.Shortcut == value.Shortcut) ?? ShortcutChoices[0];
        set { if (value is not null && this.value.Shortcut != value.Shortcut) { this.value = this.value with { Shortcut = value.Shortcut }; Changed(); } }
    }
    public string ShortcutLabel => SelectedShortcut.Label;
    public string Notice { get => notice; private set { if (notice != value) { notice = value; Changed(); } } }
    public bool HasLastResult => coordinator.Status.HasLastResult;
    public bool IsRecording => coordinator.Status.State == DictationState.Recording;
    public bool IsBusy => coordinator.Status.State is DictationState.Recording or DictationState.Transcribing or DictationState.Inserting;

    public bool TrySetShortcut(Resenha.Core.Shortcut shortcut)
    {
        if (ShortcutPolicy.Validate(shortcut) != ErrorCode.None)
        {
            Notice = "Esse atalho é reservado ou inseguro. Escolha outra combinação.";
            return false;
        }
        value = value with { Shortcut = shortcut };
        if (ShortcutChoices.All(choice => choice.Shortcut != shortcut))
        { ShortcutChoices.Add(new("Atalho personalizado", shortcut)); }
        Notice = "Novo atalho capturado. Salve para aplicar.";
        Changed(nameof(SelectedShortcut));
        Changed(nameof(ShortcutLabel));
        return true;
    }

    public void UpdateMicrophones(IReadOnlyList<MicrophoneEndpoint> microphones)
    {
        Microphones = microphones;
        if (SelectedMicrophone is null)
        {
            var selected = microphones.FirstOrDefault(item => item.IsDefault) ?? microphones.FirstOrDefault();
            value = value with { MicrophoneEndpointId = selected?.Id ?? string.Empty };
        }
        Changed(nameof(Microphones));
        Changed(nameof(SelectedMicrophone));
        Changed(nameof(MicrophoneNotice));
    }

    public async ValueTask RefreshMicrophonesAsync(CancellationToken cancellationToken = default)
    {
        var result = await enumerateMicrophones(AttemptId.New(), cancellationToken);
        if (!result.IsSuccess)
        {
            Notice = "Não foi possível atualizar os microfones.";
            return;
        }
        UpdateMicrophones(result.Value!);
        Notice = Microphones.Count == 0 ? "Nenhum microfone encontrado." : "Microfones atualizados";
    }

    public async ValueTask<Outcome<Unit>> SaveAsync(CancellationToken cancellationToken = default)
    {
        var result = await applyPreferences(value, cancellationToken);
        if (result.IsSuccess)
        {
            result = await preferences.SaveAsync(result.Attempt, value, cancellationToken);
        }
        Notice = result.IsSuccess ? "Preferências salvas" : "Não foi possível salvar as preferências";
        if (result.IsSuccess) { await coordinator.AcknowledgeFailureAsync(); }
        return result;
    }

    public async ValueTask<Outcome<Unit>> DownloadModelAsync(CancellationToken cancellationToken = default)
    {
        Notice = "Baixando o modelo local (181 MB)…";
        var result = await models.DownloadAsync(AttemptId.New(), cancellationToken);
        Notice = result.IsSuccess ? "Modelo local pronto" : "O modelo não foi instalado. Tente novamente.";
        if (result.IsSuccess) { await coordinator.AcknowledgeFailureAsync(); }
        return result;
    }

    public ValueTask<Outcome<Unit>> CancelAsync() => coordinator.CancelAsync();
    public async ValueTask CancelOrAcknowledgeAsync()
    {
        if (coordinator.Status.State == DictationState.Failed) { await coordinator.AcknowledgeFailureAsync(); }
        else { await coordinator.CancelAsync(); }
    }
    public ValueTask<Outcome<ClipboardToken>> CopyLastAsync() => coordinator.CopyLastAsync();
    public ValueTask<Outcome<Unit>> ClearLastResultAsync() => coordinator.ClearLastResultAsync();

    private void OnStatusChanged(DictationStatus status) => ui.Post(_ => Apply(status), null);

    private void Apply(DictationStatus status)
    {
        Notice = status.State switch
        {
            DictationState.Recording => "Ouvindo… solte para transcrever",
            DictationState.Transcribing => "Transcrevendo no seu computador…",
            DictationState.Inserting => "Inserindo no campo original…",
            DictationState.Failed => Message(status),
            _ => "Pronto para ouvir"
        };
        Changed(nameof(HasLastResult));
        Changed(nameof(IsRecording));
        Changed(nameof(IsBusy));
    }

    private static string Message(DictationStatus status) => status.Recovery?.Action switch
    {
        RecoveryAction.PasteManually => "Texto copiado. Cole manualmente com Ctrl+V.",
        RecoveryAction.CopyAgain => "Texto preservado. Use “Copiar último texto”.",
        RecoveryAction.DownloadOrImportModel => "Baixe ou importe o modelo de voz.",
        RecoveryAction.OpenMicrophoneSettings => "Libere o microfone nas Configurações do Windows.",
        RecoveryAction.ChooseMicrophone => "Escolha um microfone disponível.",
        RecoveryAction.ReopenApplication => "Feche e abra o Resenha para proteger o microfone.",
        _ => "Não foi possível concluir. Tente novamente."
    };

    private void Changed([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new(name));

    public void Dispose()
    {
        if (disposed) { return; }
        disposed = true;
        coordinator.StatusChanged -= OnStatusChanged;
    }
}

public sealed record ShortcutChoice(string Label, Resenha.Core.Shortcut Shortcut);
