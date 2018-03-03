/*
    This tests that the distribution of random bytes is uniform.
    If it is not, it indicates that something is very likely wrong.

    This test checks for statistical anomalies in the random bytes,
    using a Z-test.

    Build with:
    dmd ./test/distribution.d -I./build/interfaces/source ./build/libraries/csprng-0.1.0.a
*/
import csprng.system : CSPRNG;
import core.sys.posix.signal;
import std.stdio : writeln;

extern(C) void handler(int signalNumber) nothrow @nogc @system
{
    done = true;
}

uint[256] counts;
bool done = false;

void main()
{
    writeln("Starting distribution test. This will run forever, until you terminate with Ctrl-C.");
    signal(SIGINT, &handler);
    CSPRNG c = new CSPRNG();
    uint i = 0;
    while (i++ < uint.max && !done)
    {
        size_t index = cast(size_t) (cast(ubyte[]) c.getBytes(1))[0];
        counts[index]++;
    }
    writeln(counts);

    size_t average (uint[256] values)
    {
        size_t sum;
        foreach (value; values)
        {
            sum += value;
        }
        return (sum / 256);
    }

    real stddev (uint[256] values)
    {
        import std.math : sqrt;
        size_t avg = average(values);
        size_t sumOfSquaredDeviations;
        foreach (value; values)
        {
            sumOfSquaredDeviations += (cast(long) (value - avg))^^2;
        }
        return sqrt(cast(real) (sumOfSquaredDeviations / 256));
    }

    real zScore (real stddev, size_t average, uint value)
    {
        return ((cast(long) value - cast(long) average) / stddev);
    }

    size_t avg = average(counts);
    real sdev = stddev(counts);
    writeln("Average: ", avg);
    writeln("Std Dev: ", sdev);

    foreach (uint index, uint count; counts)
    {
        real z = zScore(sdev, avg, count);
        if (z > 3.0 || z < -3.0)
        {
            writeln("Value ", count, " at index ", index ," was abnormally distributed! Z Score: ", z);
        }
    }
}