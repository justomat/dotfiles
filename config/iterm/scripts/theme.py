#!/usr/bin/env python3

import asyncio
import iterm2

# DARK_THEME = "GitHub Dark Default (2)"
DARK_THEME = "GitHub Dark Default (2)"
# DARK_THEME = "gruvbox"
# DARK_THEME = "Mayukai Mirage Gruvbox Darktooth-1677561779054"
LIGHT_THEME = "GitHub Light Default (2)"

async def update(connection, theme):
    # Themes have space-delimited attributes, one of which will be light or dark.
    parts = theme.split(" ")
    if "dark" in parts:
        preset = await iterm2.ColorPreset.async_get(connection, DARK_THEME)
    else:
        preset = await iterm2.ColorPreset.async_get(connection, LIGHT_THEME)

    # Update the list of all profiles and iterate over them.
    profiles=await iterm2.PartialProfile.async_query(connection)
    for partial in profiles:
        # Fetch the full profile and then set the color preset in it.
        profile = await partial.async_get_full_profile()
        await profile.async_set_color_preset(preset)

async def main(connection):
    app = await iterm2.async_get_app(connection)
    await update(connection, await app.async_get_variable("effectiveTheme"))
    async with iterm2.VariableMonitor(connection, iterm2.VariableScopes.APP, "effectiveTheme", None) as mon:
        while True:
            # Block until theme changes
            theme = await mon.async_get()
            await update(connection, theme)


iterm2.run_forever(main)

