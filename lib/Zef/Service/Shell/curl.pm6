use Zef;

class Zef::Service::Shell::curl does Fetcher does Probeable does Messenger {
    method fetch-matcher($url) { $ = $url.lc.starts-with('http://' | 'https://') }

    method probe {
        state $probe = try { zrun('curl', '--help', :!out, :!err).so };
    }

    method fetch($url, IO() $save-as, AUTH :$auth = NONE) {
        die "target download directory {$save-as.parent} does not exist and could not be created"
            unless $save-as.parent.d || mkdir($save-as.parent);

        my @auth-args = ();
        if $auth === BEARER-TOKEN {
            @auth-args = ("--oauth2-bearer", "{%*ENV{'ZEF_AUTH_TOKEN'}//''}");
        }

        my $passed;
        react {
            my $cwd := $save-as.parent;
            my $ENV := %*ENV;
            my $proc = zrun-async('curl', '--silent', '-L', '-z', $save-as.absolute, '-o', $save-as.absolute, $url, |@auth-args);
            whenever $proc.stdout(:bin) { }
            whenever $proc.stderr(:bin) { }
            whenever $proc.start(:$ENV, :$cwd) { $passed = $_.so }
        }

        ($passed && $save-as.e) ?? $save-as !! False;
    }
}
