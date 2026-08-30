#!/bin/sh
# Install a portable bundle at its current location for this user.
set -eu
bundle=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
data=${XDG_DATA_HOME:-"$HOME/.local/share"}
mkdir -p "$data/applications" "$data/mime/packages"
cp "$bundle/org.sutoriraita.project.xml" "$data/mime/packages/"
# Desktop-entry quoted arguments still require escaping reserved characters.
escaped=$(printf '%s' "$bundle/sutoriraita" | sed 's/\\/\\\\/g; s/"/\\"/g; s/`/\\`/g; s/\$/\\$/g; s/%/%%/g')
cat > "$data/applications/org.sutoriraita.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Sutōrīraitā
Exec="$escaped" %f
Terminal=false
Categories=Office;
MimeType=application/x-sutoriraita;
EOF
update-mime-database "$data/mime"
update-desktop-database "$data/applications"
xdg-mime default org.sutoriraita.desktop application/x-sutoriraita
printf '%s\n' 'Registered this bundle. Run install.sh again if you move it.'
