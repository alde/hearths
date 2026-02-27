#!/bin/bash
set -euo pipefail

# Ensure Libs directory exists
mkdir -p Libs

# Checkout dependencies
echo "Checking out Libs/LibStub..."
svn checkout https://repos.wowace.com/wow/libstub/trunk Libs/LibStub
echo "Done."

echo "Checking out Libs/CallbackHandler-1.0..."
svn checkout https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0 Libs/CallbackHandler-1.0
echo "Done."

echo "Checking out Libs/AceAddon-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceAddon-3.0 Libs/AceAddon-3.0
echo "Done."

echo "Checking out Libs/AceEvent-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceEvent-3.0 Libs/AceEvent-3.0
echo "Done."

echo "Checking out Libs/AceDB-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0 Libs/AceDB-3.0
echo "Done."

echo "Checking out Libs/AceDBOptions-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceDBOptions-3.0 Libs/AceDBOptions-3.0
echo "Done."

echo "Checking out Libs/AceConsole-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceConsole-3.0 Libs/AceConsole-3.0
echo "Done."

echo "Checking out Libs/AceGUI-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceGUI-3.0 Libs/AceGUI-3.0
echo "Done."

echo "Checking out Libs/AceConfig-3.0..."
svn checkout https://repos.wowace.com/wow/ace3/trunk/AceConfig-3.0 Libs/AceConfig-3.0
echo "Done."

