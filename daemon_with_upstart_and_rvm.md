# Setting up gorgon listener using upstart

These steps will guarantee that the listener is always running and it will start when the OS boots. They have been tested using Ubuntu 12.04, but these steps should work with any OS that uses upstart. We are assuming you are using `rvm`

1. `mkdir ~/.gorgon && cd ~/.gorgon`
1. `rvm use ruby-1.9.3` or whatever version of ruby you use.
1. `gem install gorgon foreman`
1. Place your _gorgon\_listener.json_ in this directory. See [here](https://github.com/nulogy/Gorgon/blob/master/gorgon_listener.json.sample) for a _gorgon\_listener.json_ example.
1. `echo 'listener: [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" && `
   `rvm ruby-1.9.3 do gorgon listen > listener.out 2> listener.err' > Procfile`
1. ``rvmsudo foreman export upstart /etc/init -a gorgon -u `whoami` -c listener=1``
1. `sudo start gorgon`
1. open ’/etc/init/gorgon.conf’ and add `start on runlevel [2345]` at the top of the file
1. Check if listener is running: Run `tail /tmp/gorgon-remote.log` and the last line should say “Waiting for jobs…”

If you modify ~/.gorgon/gorgon_listener.json, make sure you restart the listener by running `sudo restart gorgon`
