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
import irc.eventloop;
import core.sys.posix.signal;

class DiceBot {
    private string server;
    private ushort port;
    private bool ssl;
    private string[] channels;
    private string connect_script;

    IrcClient client;
    IrcEventLoop loop;

    void delegate() callBack;

    this(string server, ushort port, bool ssl, string[] channels, string connect_script)
    {
        this.server = server;
        this.port = port;
        this.ssl = ssl;
        this.channels = channels;
        this.connect_script = connect_script;
    }

    void connect()
    {
        stdout.write("Connecting...\n");

        Address[] addr = getAddress(server, port);

        if (addr.length > 0)
        {
            Socket sock;
            if (ssl) {
                sock = new SslSocket(addr[0].addressFamily);
            } else {
                sock = new TcpSocket(addr[0].addressFamily);
            }

            client = new IrcClient(sock);
            client.onConnect ~= &onConnect;
            client.onMessage ~= &onMessage;
            client.realName = "Juno Botterson";
            client.userName = "juno6";
            client.nickName = "juno6";
            client.connect(addr[0]);
        }
    }

    void read()
    {
        if (loop)
        {
            loop.run();
        }
        else
        {
            client.read();
        }
    }

    void onConnect()
    {
        if (connect_script != "")
        {
            client.writef(connect_script);
        }

        stdout.write("Connected.\n");

        loop = new IrcEventLoop();
        loop.add(client);
        loop.postTimer(callBack, 0.5, IrcEventLoop.TimerRepeat.yes);

        foreach (string c ; channels)
        {
            stdout.writefln("Joining %s\n", c);
            client.join(c);
        }
    }

    void quit()
    {
        loop.remove(client);
        client.quit("Bye!");
    }

    void onMessage(IrcUser user, in char[] target, in char[] message)
    {
        stdout.writeln(message);

        bool pm = (target == client.nickName);
        auto reply_target = (pm)?user.nickName:target;
        
        alias tmap = map!(map!(text));
        alias cconcat = reduce!((a,b) => a ~ ", " ~ b);
        alias sconcat = reduce!((a,b) => a ~ "), (" ~ b);
        alias rsum = reduce!((a,b) => a + b);

        if (message[0] == '!')
        {
            auto m = match(message[1.. message.length], r"^(\d+)d(\d+)(f?)([\s:](.*))?$");
            if (m)
            {
                int num_dice = to!int(m.captures[1]);
                int die_size = to!int(m.captures[2]);
                bool floating = m.captures[3] == "f";
                auto msg = strip(chompPrefix(m.captures[5], ":"));
                client.sendf(reply_target, "Rolling %d d%d %s (%s)", num_dice, die_size, (floating?"floating":""),msg);

                auto rolls = array(roll(num_dice, die_size, floating));

                auto textrolls = array(tmap(rolls));

                string res = "Result: ("
                    ~ sconcat(
                            map!(cconcat)(textrolls)
                      )
                    ~ ") = "
                    ~ text(sum(map!(sum)(rolls)));

                client.send(reply_target, res);
                return;
            }
            m = match(message[1.. message.length], r"^sr3 (\d+)([\s](\d+))?([\s:](.*))?$");
            if (m)
            {
                int num_dice = to!int(m.captures[1]);
                int tn = (m.captures[2] != "") ? to!int(m.captures[3]) : 4;
                auto msg = strip(chompPrefix(m.captures[5], ":"));

                client.sendf(reply_target, "Roll %d dice vs %d (%s)", num_dice, tn, msg);

                auto rolls = array(roll(num_dice, 6, true));
                auto textrolls = array(tmap(rolls));

                auto sums = map!(sum)(rolls);

                writeln(sums);

                auto sux = filter!(a=>a>=tn)(sums).count();

                string res = "Result: ("
                    ~ sconcat(
                            map!(cconcat)(textrolls)
                      )
                    ~ "); Sux = "
                    ~ to!string(sux);

                client.sendf(reply_target, res);
                return;
            }
 
            
        }
    }

    auto roll(int num_dice, int die_size, bool floating)
    {
        return map!(a => roll_one(die_size, floating))(new int[num_dice]);
    }

    auto roll_one(int die_size, bool floating)
    {
        auto rolls = make!(Array!int)();

        do
        {
            rolls ~= uniform(1,die_size+1);
        }
        while(rolls.back == die_size && floating);

        return array(rolls);
    }

}
