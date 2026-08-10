# .dotfiles
- Personal dotfiles config and setup using `Stow`. Works on several different Linux distributions.
- Will automatically source additional config files from optional subfolders.

Install using this curl command:

```bash
curl -sSL https://raw.githubusercontent.com/Drauku/.dotfiles/refs/heads/master/install.sh | bash
```

If you prefer to use `wget` instead of `curl`:

```bash
wget -qO- https://raw.githubusercontent.com/Drauku/.dotfiles/refs/heads/master/install.sh | bash
```

If you prefer to download and check the code (recommended):
```bash
curl -sSLO https://raw.githubusercontent.com/Drauku/.dotfiles/master/install.sh -o install.sh
```

- Verify the script is safe, then `chmod +x install.sh` and run it: `./install.sh`.
