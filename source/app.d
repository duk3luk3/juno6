import std.stdio;
import std.getopt;
import std.socket;
import std.regex;
import ssl.socket;
import std.string;
import std.conv;
import std.random;
import std.container;
import std.range;
import std.algorithm;
import irc.client;
import core.sys.posix.signal;
import dicebot;

int _run = true;

DiceBot bot;

void main(string[] args)
{
    signal(SIGINT, &sighandler);

    string server = "irc.foonetic.net";
    ushort port = 6667;
    bool ssl = false;
    string[] channels = ["#greenroom"];
    string connect_script = "";

    getopt(
            args,
            "server|s", &server,
            "port|p", &port,
            "ssl", &ssl,
            "channel", &channels,
            "script", &connect_script
          );

    void callBack()
    {
        if (!_run) {
            bot.quit();
        }
    }

    bot = new DiceBot(server, port, ssl, channels, connect_script);
    bot.callBack = &callBack;

    bot.connect();
}


extern(C) nothrow void sighandler(int sig) @nogc @system
{
    if (sig == SIGINT)
        _run = false;
}
