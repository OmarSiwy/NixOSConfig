#!/usr/bin/env python3
# fuzzel launches apps with SIGCHLD set to SIG_IGN (to auto-reap them). That
# disposition is inherited across exec, so Chromium/QtWebEngine apps (qutebrowser)
# abort during sandbox init: their waitpid() returns ECHILD ("No child processes")
# because the kernel auto-reaped the probe child. rofi avoided this by launching
# via GLib g_spawn, which resets child signals. Reset SIGCHLD here, then exec.
import os
import signal
import sys

signal.signal(signal.SIGCHLD, signal.SIG_DFL)
os.execvp(sys.argv[1], sys.argv[1:])
