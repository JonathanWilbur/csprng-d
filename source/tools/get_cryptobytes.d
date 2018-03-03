version (Windows)
{
    import core.sys.windows.windows;
    SetConsoleMode(GetStdHandle(cast(short) -11), 0x0007);
}