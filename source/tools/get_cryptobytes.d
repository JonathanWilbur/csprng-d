int main (string[] args)
{
    import csprng.system;
    import std.conv : ConvException, ConvOverflowException, to;
    import std.stdio : stderr, stdout, writeln;

    CSPRNG c;
    try
    {
        c = new CSPRNG();
    }
    catch (CSPRNGException e)
    {
        stderr.writeln(e.msg);
        return 2;
    }

    if (args.length != 2u)
    {
        writeln("Usage: get-cryptobytes [number of bytes]\n");
        version (Windows)
        {
            if (c.isUsingCNGAPI)
            {
                writeln
                (
                    "On your system, the Windows Cryptography: Next Generation API " ~
                    "will be used to generate cryptographically-secure pseudo-random " ~
                    "bytes when using the csprng library. This functionality comes " ~
                    "from Bcrypt.dll.\r\n"
                );
            }
            else if (c.isUsingCryptoAPI)
            {
                writeln
                (
                    "On your system, the Windows CryptoAPI will be used to " ~
                    "generate cryptographically-secure pseudo-random bytes " ~
                    "when using the csprng library. This functionality comes " ~
                    "from advapi32.dll.\r\n"
                );
            }
            else if (c.isUsingRtlGenRandom)
            {
                writeln
                (
                    "On your system, the Windows RtlGenRandom function will be " ~
                    "used to generate cryptographically-secure pseudo-random " ~
                    "bytes when using the csprng library. This functionality " ~
                    "comes from advapi32.dll.\r\n"
                );
            }
            else
            {
                assert(0u, "Invalid CSPRNG state. Windows library load state is uncertain.");
            }
        }
        else version (Posix)
        {
            writeln
            (
                "On your system, the /dev/random pseudo-device will be " ~
                "used to generate cryptographically-secure pseudo-random " ~
                "bytes when using the csprng library.\n"
            );
        }
        else
        {
            static assert
            (
                0u,
                "The get-cryptobytes tool cannot be compiled, because your operating system " ~
                "is unsupported. The csprng library and the get-cryptobytes command-line tool, " ~
                "currently, can only compile on Windows, Mac OS X, Linux, and possibly Solaris and the BSDs."
            );
        }
        return 1;
    }

    void[] ret;
    try
    {
        ret = c.getBytes(args[1].to!size_t);
    }
    catch (CSPRNGException e)
    {
        stderr.writeln(e.msg);
        return 3;
    }
    catch (ConvOverflowException e)
    {
        stderr.writeln(e.msg);
        return 4;
    }
    catch (ConvException e)
    {
        stderr.writeln(e.msg);
        return 5;
    }

    stdout.rawWrite(ret);
    return 0;
}