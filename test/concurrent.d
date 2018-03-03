/*
    For testing a program that is using multiple CSPRNGs at once.

    Temporarily change CSPRNG.readBufferSize to 10.
    Compile with:
    dmd ./test/concurrent.d -I./build/interfaces/source ./build/libraries/csprng-0.1.0.a
*/
import csprng.system : CSPRNG;
import std.concurrency : spawn, Tid;
import std.stdio : writeln;

void write_a() { CSPRNG a = new CSPRNG(); writeln(a.getBytes(9)); }
void write_b() { CSPRNG b = new CSPRNG(); writeln(b.getBytes(11)); }
void write_c() { CSPRNG c = new CSPRNG(); writeln(c.getBytes(10)); }

void main()
{
    const Tid thread_a = spawn(&write_a);
    const Tid thread_b = spawn(&write_b);
    const Tid thread_c = spawn(&write_c);
    writeln("Done.");
}