int main (string[] args)
{
    import csprng.system;
    import std.conv : to;
    import std.stdio : stderr, stdout, writeln;

    if (args.length != 2u)
    {
        writeln("Please supply exactly two arguments.");
        return -1;
    }

    size_t demandedBytes = args[1].to!size_t;
    CSPRNG c = new CSPRNG();
    stdout.rawWrite(c.getBytes(demandedBytes));
    return 0;
}