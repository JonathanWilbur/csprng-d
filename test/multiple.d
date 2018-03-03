/*
    For testing a program that is using multiple CSPRNGs at once.

    Temporarily change CSPRNG.readBufferSize to 10.
    Compile with:
    dmd ./test/multiple.d -I./build/interfaces/source ./build/libraries/csprng-0.1.0.a
*/
import csprng.system : CSPRNG;
import std.stdio : writeln;
void main()
{
    { // An enclosing scope so I can ensure that the destructors are called.
        CSPRNG a = new CSPRNG();
        CSPRNG b = new CSPRNG();
        CSPRNG c = new CSPRNG();
        writeln(a.getBytes(9));
        writeln(b.getBytes(11));
        writeln(c.getBytes(10));
    }
    writeln("Done.");
}