using System.Runtime.InteropServices;
using System.Text;

namespace Resenha.Platform;

public sealed class OpenRouterCredentialStore
{
    private const string Target = "Resenha/OpenRouter";
    private const uint Generic = 1;
    private const uint LocalMachinePersistence = 2;

    public bool HasCredential => Read() is not null;

    public string? Read()
    {
        if (!OperatingSystem.IsWindows()) { return null; }
        if (!CredRead(Target, Generic, 0, out var pointer)) { return null; }
        try
        {
            var credential = Marshal.PtrToStructure<Credential>(pointer);
            if (credential.CredentialBlob == IntPtr.Zero || credential.CredentialBlobSize is 0 or > 1024) { return null; }
            var value = Marshal.PtrToStringUni(credential.CredentialBlob,
                checked((int)credential.CredentialBlobSize / 2));
            return IsValid(value) ? value : null;
        }
        finally { CredFree(pointer); }
    }

    public bool Save(string value)
    {
        if (!OperatingSystem.IsWindows() || !IsValid(value)) { return false; }
        var bytes = Encoding.Unicode.GetBytes(value);
        var blob = Marshal.AllocCoTaskMem(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            var credential = new Credential
            {
                Type = Generic,
                TargetName = Target,
                CredentialBlobSize = checked((uint)bytes.Length),
                CredentialBlob = blob,
                Persist = LocalMachinePersistence,
                UserName = Environment.UserName
            };
            return CredWrite(ref credential, 0);
        }
        finally
        {
            Array.Clear(bytes);
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            Marshal.FreeCoTaskMem(blob);
        }
    }

    public bool Delete() => !OperatingSystem.IsWindows() || CredDelete(Target, Generic, 0)
        || Marshal.GetLastWin32Error() == 1168;

    public static bool IsValid(string? value) => value is { Length: >= 20 and <= 256 }
        && value.StartsWith("sk-or-", StringComparison.Ordinal)
        && value.All(character => !char.IsWhiteSpace(character) && !char.IsControl(character));

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags;
        public uint Type;
        public string? TargetName;
        public string? Comment;
        public long LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string? TargetAlias;
        public string? UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern bool CredWrite(ref Credential credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr buffer);
}
