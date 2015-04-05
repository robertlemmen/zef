use Zef::Phase::Getting;
use JSON::Tiny;
use IO::Socket::SSL;
use MIME::Base64;

class Zef::Getter does Zef::Phase::Getting {

    has @.plugins;

    # TODO: load plugins if .does or .isa matches
    # so our code doesnt look like modules are
    # reloaded for every phase.
    submethod BUILD(:@!plugins) {
        for @!plugins -> $p { 
            self does ::($p) if do { require ::($p); ::($p).does(Zef::Phase::Getting) };
        }
    }

    multi method get(:$save-to is copy = $*TMPDIR, *@modules) {
        my $sock = IO::Socket::SSL.new(:host<zef.pm>, :port(443));
        my @fetched;
        my @failed;

        for @modules -> $module {
            temp $save-to = $*SPEC.catdir($save-to, $module);
            my $data   = to-json({
                name => $module,
            });

            $sock.send("POST /api/download HTTP/1.0\r\nConnection: close\r\nHost: zef.pm\r\nContent-Length: {$data.chars}\r\n\r\n$data\r\n");
            my $recv  = '';
            while my $r = $sock.recv { $recv ~= $r; }
            $recv = $recv.split("\r\n\r\n",2)[1].substr(0, *-2);
            my $mode  = 0o0644;
            try { mkdir $save-to } or fail "error: $_";
            for @($recv.split("\r\n")) -> $path is copy, $enc is copy {
                ($mode, $path) = $path.split(':', 2);
                KEEP @fetched.push($path);
                UNDO @failed.push($path);

                # Handle directory creation
                my IO::Path $dir = $*SPEC.catdir($save-to, $path.IO.dirname).IO;
                try { mkdir $dir } or fail "error: $_";

                # Handle file creation
                my $fh = $*SPEC.catpath('', $dir, $path.IO.basename).IO.open(:w);
                my $dc = MIME::Base64.decode($enc);
                $fh.write($dc) or fail "write error: $_";
                $fh.close;
                say $*SPEC.catpath('', $dir, $path.IO.basename);
                $*SPEC.catpath('', $dir, $path.IO.basename).IO.chmod($mode.Int);
            }
        }

        return %(@fetched.map({ $_ => True }), @failed.map({ $_ => False }));
    }
}
