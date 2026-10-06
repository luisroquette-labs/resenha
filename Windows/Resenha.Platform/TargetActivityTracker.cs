using Resenha.Core;

namespace Resenha.Platform;

public enum UserActivityKind { Keyboard, Mouse, ObserverLost }

public interface IUserActivitySink
{
    void Observe(UserActivityKind kind);
}

public sealed class TargetActivityTracker : IUserActivitySink
{
    private readonly object gate = new();
    private AttemptId? active;
    private long generation;
    private bool unsafeState;
    private bool observerLost;

    public long? Begin(AttemptId attempt)
    {
        attempt.ThrowIfEmpty();
        lock (gate)
        {
            if (active is not null) { return null; }
            active = attempt;
            generation = 0;
            unsafeState = observerLost;
            return generation;
        }
    }

    public void Observe(UserActivityKind kind)
    {
        lock (gate)
        {
            if (kind == UserActivityKind.ObserverLost) { observerLost = true; unsafeState = true; }
            if (active is null) { return; }
            generation = checked(generation + 1);
        }
    }

    public (long Generation, bool Safe) Read(AttemptId attempt)
    {
        lock (gate)
        {
            return active == attempt ? (generation, !unsafeState) : (-1, false);
        }
    }

    public void End(AttemptId attempt)
    {
        lock (gate)
        {
            if (active == attempt) { active = null; unsafeState = true; }
        }
    }
}
