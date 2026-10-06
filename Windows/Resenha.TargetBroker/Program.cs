using System.IO;
using System.IO.Pipes;
using System.Text.Json;

namespace Resenha.TargetBroker;

internal static class Program
{
    [MTAThread]
    private static int Main(string[] arguments)
    {
        if (arguments.Length != 6 || arguments[0] != "--pipe" || arguments[2] != "--attempt" || arguments[4] != "--nonce"
            || arguments[1].Length is < 20 or > 128 || arguments[5].Length != 64
            || !Guid.TryParseExact(arguments[3], "D", out var attempt)) { return 2; }
        try
        {
            using var pipe = new NamedPipeClientStream(".", arguments[1], PipeDirection.Out, PipeOptions.Asynchronous);
            pipe.Connect(250);
            var payload = JsonSerializer.SerializeToUtf8Bytes(FocusProbe.Capture(attempt, arguments[5]));
            if (payload.Length > 64 * 1024) { return 3; }
            using var writer = new BinaryWriter(pipe, System.Text.Encoding.UTF8, leaveOpen: true);
            writer.Write(payload.Length);
            writer.Write(payload);
            writer.Flush();
            return 0;
        }
        catch { return 4; }
    }
}
