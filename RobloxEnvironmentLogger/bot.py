import asyncio
from io import BytesIO
import shutil
import time
from urllib.parse import urlparse
import aiohttp
import discord
from discord.ui import Button, View
from discord.ext import commands
import os
import subprocess
import requests
import tempfile
import sys
import json
from pathlib import Path
import platform
import random
import string
from dotenv import load_dotenv
from datetime import datetime, timezone

load_dotenv()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix='.', intents=intents, help_command=None)

SETTINGS_FILE = Path("bot_settings.json")
CREDITS_FILE = Path("credits.json")
PROMETHEUS_CLI_PATH = "./Prometheus/cli.lua"
LUA_EXECUTABLE = "lua"
PRESET = "Medium"
OUTPUT_FILENAME = "protected_lularph.lua"
FILES_DIR = "files"
MOON_EXECUTABLE = os.getenv("MOON_EXECUTABLE", "moon.exe")
OWNER_ID = os.getenv("1463891440831823932")  # required for .addcredits

# -------------------------------------------------------------------
# Credit system
# -------------------------------------------------------------------
def load_credits():
    if CREDITS_FILE.exists():
        try:
            with open(CREDITS_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_credits(data):
    with open(CREDITS_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def get_user_credits(user_id):
    data = load_credits()
    user_id_str = str(user_id)
    now = datetime.now(timezone.utc).timestamp()
    if user_id_str not in data:
        data[user_id_str] = {"credits": 5, "last_reset": now}
        save_credits(data)
        return 5
    else:
        # Check if 24h passed
        last = data[user_id_str].get("last_reset", 0)
        if now - last > 86400:  # 24h
            data[user_id_str]["credits"] = 5
            data[user_id_str]["last_reset"] = now
            save_credits(data)
            return 5
        return data[user_id_str].get("credits", 0)

def deduct_credit(user_id):
    data = load_credits()
    user_id_str = str(user_id)
    now = datetime.now(timezone.utc).timestamp()
    if user_id_str not in data:
        data[user_id_str] = {"credits": 5, "last_reset": now}
        data[user_id_str]["credits"] = 4  # deduct from 5
        save_credits(data)
        return True
    else:
        # Check reset first
        last = data[user_id_str].get("last_reset", 0)
        if now - last > 86400:
            data[user_id_str]["credits"] = 5
            data[user_id_str]["last_reset"] = now
        if data[user_id_str]["credits"] <= 0:
            return False
        data[user_id_str]["credits"] -= 1
        save_credits(data)
        return True

# -------------------------------------------------------------------
# Helper: send long text as file if needed
# -------------------------------------------------------------------
async def send_long_text(ctx, content, filename="output.txt", prefix=""):
    """Send content, automatically upload as file if too long."""
    if len(content) <= 1900:
        await ctx.send(prefix + content)
    else:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as f:
            f.write(content)
            temp_path = f.name
        await ctx.send(prefix, file=discord.File(temp_path, filename))
        os.remove(temp_path)

async def send_large_file(ctx, content, base_filename="output", extension=".lua", max_size=7_000_000):
    """Split content into multiple files and send them if single file exceeds max_size."""
    if len(content.encode('utf-8')) <= max_size:
        # Single file
        with tempfile.NamedTemporaryFile(mode='w', suffix=extension, delete=False, encoding='utf-8') as f:
            f.write(content)
            path = f.name
        await ctx.send(file=discord.File(path, filename=base_filename + extension))
        os.remove(path)
        return

    # Split into chunks
    parts = []
    current_part = []
    current_size = 0
    lines = content.splitlines(True)  # keep line breaks
    for line in lines:
        line_size = len(line.encode('utf-8'))
        if current_size + line_size > max_size and current_part:
            parts.append(''.join(current_part))
            current_part = [line]
            current_size = line_size
        else:
            current_part.append(line)
            current_size += line_size
    if current_part:
        parts.append(''.join(current_part))

    for i, part in enumerate(parts, start=1):
        with tempfile.NamedTemporaryFile(mode='w', suffix=extension, delete=False, encoding='utf-8') as f:
            f.write(part)
            path = f.name
        await ctx.send(f"Part {i}/{len(parts)}:", file=discord.File(path, filename=f"{base_filename}_part{i}{extension}"))
        os.remove(path)

# -------------------------------------------------------------------
# Advanced embedded Lua deobfuscator (dumper.lua)
# -------------------------------------------------------------------
DUMPER_LUA = r'''--[[
    Advanced Universal Lua Deobfuscator
    Handles multiple obfuscation types with a powerful pipeline.
]]
local function decode_hex(str)
    return (str:gsub("\\x([0-9a-fA-F][0-9a-fA-F])", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function decode_octal(str)
    return (str:gsub("\\([0-7][0-7]?[0-7]?)", function(oct)
        return string.char(tonumber(oct, 8))
    end))
end

local function decode_unicode(str)
    return (str:gsub("\\u{([0-9a-fA-F]+)}", function(hex)
        return utf8.char(tonumber(hex, 16))
    end))
end

local function remove_junk_assignments(code)
    -- Remove lines like _0x123 = nil;
    code = code:gsub("_[%w_]+%s*=%s*nil%s*;?\n?", "")
    -- Remove assignments to single underscores or short names (common junk)
    code = code:gsub("[_%l][%w_]*%s*=%s*[%w_]+%s*;?\n?", "")
    -- Remove empty statements
    code = code:gsub(";%s*\n", "\n")
    return code
end

local function simplify_var_names(code)
    -- Replace obfuscated hex variable names (like _0x123456) with v1, v2...
    local var_map = {}
    local counter = 1
    code = code:gsub("(_0x[0-9a-fA-F]+)", function(name)
        if not var_map[name] then
            var_map[name] = "v" .. counter
            counter = counter + 1
        end
        return var_map[name]
    end)
    return code
end

local function flatten_if(code)
    -- Remove obvious junk if statements: if true then ... end
    code = code:gsub("if%s+true%s+then%s*(.-)%s*end", "%1")
    -- if false then ... end -> remove completely
    code = code:gsub("if%s+false%s+then.-end", "")
    return code
end

local function beautify(code)
    -- Basic pretty-print: add newlines after certain tokens
    code = code:gsub("([%]%)}])", "%1\n")
    code = code:gsub("(function%s*%([^%)]*%))", "%1\n")
    -- Indent (simplistic)
    local indent = 0
    local lines = {}
    for line in code:gmatch("[^\n]+") do
        line = line:gsub("^%s+", "")
        if line:match("^end") then indent = indent - 1 end
        local indent_str = string.rep("    ", indent)
        if line:match("function%s*%(") or line:match("then%s*$") then
            lines[#lines+1] = indent_str .. line
            indent = indent + 1
        elseif line:match("^end") then
            lines[#lines+1] = indent_str .. line
        else
            lines[#lines+1] = indent_str .. line
        end
    end
    return table.concat(lines, "\n")
end

local function deobfuscate(input_file)
    local f = io.open(input_file, "rb")
    if not f then
        io.stderr:write("Cannot open input file\n")
        return
    end
    local data = f:read("*all")
    f:close()

    -- Try to detect if it's bytecode (first byte == 27)
    if data:byte(1) == 27 then
        io.stderr:write("BYTECODE_DETECTED\n")
        return nil
    end

    local code = data

    -- Stage 1: Decode escapes
    code = decode_hex(code)
    code = decode_octal(code)
    code = decode_unicode(code)

    -- Stage 2: Remove junk assignments
    code = remove_junk_assignments(code)

    -- Stage 3: Simplify variable names
    code = simplify_var_names(code)

    -- Stage 4: Flatten control flow
    code = flatten_if(code)

    -- Stage 5: Beautify
    code = beautify(code)

    io.write(code)
end

local input_file = arg[1]
if not input_file then
    io.stderr:write("Usage: lua dumper.lua <input_file>\n")
    os.exit(1)
end
deobfuscate(input_file)
'''

# -------------------------------------------------------------------
# Settings and helpers
# -------------------------------------------------------------------
DEFAULT_SETTINGS = {
    "hookOp": False,
    "explore_funcs": True,
    "spyexeconly": False,
    "no_string_limit": False,
    "minifier": False,
    "comments": True,
    "ui_detection": False,
    "notify_scamblox": False,
    "constant_collection": False,
    "duplicate_searcher": False,
    "neverNester": False
}

SETTING_DESCRIPTIONS = {
    "hookOp": "Hook operations (repeat, while, if, comparisons)",
    "explore_funcs": "Show full function bodies",
    "spyexeconly": "Only spy executor variables",
    "no_string_limit": "No string truncation",
    "minifier": "Minify/inline output",
    "comments": "Show helpful comments",
    "ui_detection": "Detect UI libraries [EXPERIMENTAL]",
    "notify_scamblox": "Notify scam detection (Premium only)",
    "constant_collection": "Collect all strings",
    "duplicate_searcher": "Search for duplicate files",
    "neverNester": "Prevent nested if checks"
}

async def get_code_from_context(ctx, code_arg):
    if code_arg is None and ctx.message.attachments:
        attachment = ctx.message.attachments[0]
        if attachment.filename.endswith(('.txt', '.lua', '.luau')):
            file_data = await attachment.read()
            return file_data.decode('utf-8'), None
        else:
            return None, "Please attach a `.txt`, `.lua`, or `.luau` file."
    elif code_arg is not None:
        return code_arg, None
    else:
        return None, "Please provide Luau code or attach a file."

async def get_bytes_from_attachment(attachment):
    """Read attachment as bytes (for binary detection)."""
    return await attachment.read()

def generate_random_filename(length=16, extension=""):
    letters = string.ascii_lowercase + string.digits
    name = ''.join(random.choice(letters) for _ in range(length))
    return f"{name}{extension}"

# -------------------------------------------------------------------
# Moon compilation
# -------------------------------------------------------------------
async def run_moon_compile(input_code: str) -> tuple[bytes, str]:
    with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as f:
        f.write(input_code)
        input_path = f.name
    output_name = generate_random_filename(16, ".luac")
    output_path = os.path.abspath(output_name)
    try:
        my_env = os.environ.copy()
        if platform.system() == "Linux":
            my_env["LD_LIBRARY_PATH"] = "/usr/lib:/usr/local/lib"
        cmd = [MOON_EXECUTABLE, "-dev", "-i", input_path, "-o", output_path]
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=my_env
        )
        stdout, stderr = await process.communicate()
        if process.returncode != 0:
            error_msg = stderr.decode().strip() or stdout.decode().strip()
            raise Exception(f"Moon compilation failed: {error_msg}")
        if not os.path.exists(output_path):
            raise Exception("Output file not created")
        with open(output_path, 'rb') as f:
            bytecode = f.read()
        return bytecode, output_name
    finally:
        try:
            os.remove(input_path)
        except:
            pass

# -------------------------------------------------------------------
# Prometheus obfuscation
# -------------------------------------------------------------------
async def run_prometheus(input_code: str) -> tuple[str, float]:
    start_time = time.time()
    os.makedirs(FILES_DIR, exist_ok=True)
    input_path = os.path.join(FILES_DIR, "input.lua")
    output_path = os.path.join(FILES_DIR, "output.lua")
    try:
        with open(input_path, 'w', encoding='utf-8') as f:
            f.write(input_code)
        command = [LUA_EXECUTABLE, PROMETHEUS_CLI_PATH, "--preset", PRESET, input_path, "--out", output_path]
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        if process.returncode != 0:
            error_msg = stderr.decode().strip() or stdout.decode().strip()
            raise Exception(f"Prometheus failed: {error_msg}")
        if not os.path.exists(output_path):
            raise Exception("Output file not created")
        with open(output_path, 'r', encoding='utf-8') as f:
            obfuscated = f.read()
        end_time = time.time()
        return obfuscated, (end_time - start_time) * 1000
    finally:
        shutil.rmtree(FILES_DIR, ignore_errors=True)

# -------------------------------------------------------------------
# Settings management
# -------------------------------------------------------------------
def load_settings():
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_settings(settings):
    with open(SETTINGS_FILE, 'w') as f:
        json.dump(settings, f, indent=2)

def get_user_settings(user_id):
    all_settings = load_settings()
    user_id_str = str(user_id)
    if user_id_str not in all_settings:
        all_settings[user_id_str] = DEFAULT_SETTINGS.copy()
        save_settings(all_settings)
    return all_settings[user_id_str]

def update_user_setting(user_id, setting_name, value):
    all_settings = load_settings()
    user_id_str = str(user_id)
    if user_id_str not in all_settings:
        all_settings[user_id_str] = DEFAULT_SETTINGS.copy()
    all_settings[user_id_str][setting_name] = value
    save_settings(all_settings)

class SettingsView(View):
    def __init__(self, user_id, settings):
        super().__init__(timeout=300)
        self.user_id = user_id
        self.settings = settings
        self.create_buttons()

    def create_buttons(self):
        self.clear_items()
        for setting_name, description in SETTING_DESCRIPTIONS.items():
            is_enabled = self.settings.get(setting_name, False)
            button = Button(
                label=f"{'✅' if is_enabled else '❌'} {setting_name}",
                style=discord.ButtonStyle.success if is_enabled else discord.ButtonStyle.secondary,
                custom_id=setting_name
            )
            button.callback = self.create_callback(setting_name)
            self.add_item(button)

    def create_callback(self, setting_name):
        async def callback(interaction: discord.Interaction):
            if interaction.user.id != self.user_id:
                await interaction.response.send_message("❌ These are not your settings!", ephemeral=True)
                return
            current_value = self.settings.get(setting_name, False)
            new_value = not current_value
            update_user_setting(self.user_id, setting_name, new_value)
            self.settings[setting_name] = new_value
            self.create_buttons()
            embed = create_settings_embed(self.settings)
            await interaction.response.edit_message(embed=embed, view=self)
        return callback

def create_settings_embed(settings):
    embed = discord.Embed(
        title="⚙️ Script Logger Settings",
        description="Click buttons below to toggle settings on/off",
        color=discord.Color.blue()
    )
    for setting_name, description in SETTING_DESCRIPTIONS.items():
        is_enabled = settings.get(setting_name, False)
        status = "✅ Enabled" if is_enabled else "❌ Disabled"
        embed.add_field(
            name=f"{setting_name}",
            value=f"{description}\n**Status:** {status}",
            inline=False
        )
    return embed

# -------------------------------------------------------------------
# Bot events and existing commands
# -------------------------------------------------------------------
@bot.event
async def on_ready():
    print(f'✅ Logged in as {bot.user}')

@bot.command(name='obfuscate')
async def obfuscate_prefix(ctx, *, code: str = None):
    if ctx.guild is not None:
        await ctx.send("❌ This command can only be used in DMs to protect your code.")
        return
    input_code, error = await get_code_from_context(ctx, code)
    if error:
        await ctx.send(error)
        return
    try:
        obfuscated_code, processing_time = await run_prometheus(input_code)
        with BytesIO(obfuscated_code.encode('utf-8')) as file:
            file.seek(0)
            await ctx.send(
                content=f"✅ Obfuscated in `{processing_time:.2f} ms`",
                file=discord.File(file, filename=OUTPUT_FILENAME)
            )
    except Exception as e:
        await ctx.send(f"⚠️ Error: {e}")

@bot.command(name='help')
async def help_command(ctx):
    credits = get_user_credits(ctx.author.id)
    await ctx.send(f"""
**Available Commands:**
- `.obfuscate <code or attach file>`: Obfuscate Luau code using Prometheus (DM only).
- `.get <url>`: Fetch content from a URL and return it as a file.
- `.settings`: View and toggle your script logger settings.
- `.l <code or attach file or URL>`: Run the environment logger (code reconstructor) **[1 credit]**.
- `.luadump <code or attach file or URL>`: Run the universal Lua deobfuscator **[1 credit]**.
- `.moon <code or attach file or URL>`: Compile Lua to bytecode using MoonSec deobfuscator **[1 credit]**.
- `.addcredits @user amount`: Add credits to a user (owner only).
- `.credits`: Check your current credit balance.

You have **{credits}** credits left today.
""")

@bot.command(name='get')
async def get_prefix(ctx, url: str = None):
    if url is None:
        await ctx.send("❌ Please provide a URL. Example: `.get https://example.com`")
        return
    if not url.startswith(("http://", "https://")):
        await ctx.send("❌ URL must start with http:// or https://")
        return
    await ctx.defer()
    headers = {"User-Agent": "Roblox/WinInetRobloxApp/0.708.0.7080878"}
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers, timeout=15) as resp:
                if resp.status != 200:
                    await ctx.send(f"❌ HTTP error {resp.status}")
                    return
                content_type = resp.headers.get("Content-Type", "")
                if "text" in content_type or "json" in content_type or "javascript" in content_type:
                    content = await resp.text()
                    mode = 'text'
                else:
                    content = await resp.read()
                    mode = 'binary'
                filename = None
                content_disposition = resp.headers.get("Content-Disposition")
                if content_disposition and "filename=" in content_disposition:
                    parts = content_disposition.split("filename=")
                    if len(parts) > 1:
                        filename = parts[1].strip('"\'')
                        if ';' in filename:
                            filename = filename.split(';')[0]
                if not filename:
                    parsed = urlparse(url)
                    path = parsed.path
                    filename = path.split('/')[-1] if path and '/' in path else "response.txt"
                    if not filename:
                        filename = "response.txt"
                if mode == 'text' and not filename.endswith(('.txt', '.html', '.htm', '.json', '.js', '.css', '.xml')):
                    filename += '.txt'
                elif mode == 'binary' and '.' not in filename:
                    filename += '.bin'
                file_obj = BytesIO(content.encode('utf-8') if mode == 'text' else content)
                discord_file = discord.File(file_obj, filename=filename)
                await ctx.send(f"✅ Fetched `{url}`", file=discord_file)
    except asyncio.TimeoutError:
        await ctx.send("❌ Request timed out (15 seconds).")
    except aiohttp.ClientError as e:
        await ctx.send(f"❌ Network error: {e}")
    except Exception as e:
        await ctx.send(f"❌ Unexpected error: {e}")

@bot.command(name='settings')
async def settings_command(ctx):
    user_settings = get_user_settings(ctx.author.id)
    embed = create_settings_embed(user_settings)
    view = SettingsView(ctx.author.id, user_settings)
    await ctx.send(embed=embed, view=view)

# -------------------------------------------------------------------
# Credit commands
# -------------------------------------------------------------------
@bot.command(name='credits')
async def credits_command(ctx):
    credits = get_user_credits(ctx.author.id)
    await ctx.send(f"💰 You have **{credits}** credits remaining today.")

@bot.command(name='addcredits')
async def addcredits_command(ctx, member: discord.Member, amount: int):
    if str(ctx.author.id) != OWNER_ID:
        await ctx.send("❌ Only the bot owner can use this command.")
        return
    if amount <= 0:
        await ctx.send("❌ Amount must be positive.")
        return
    data = load_credits()
    uid = str(member.id)
    now = datetime.now(timezone.utc).timestamp()
    if uid not in data:
        data[uid] = {"credits": 5, "last_reset": now}
    data[uid]["credits"] += amount
    save_credits(data)
    await ctx.send(f"✅ Added {amount} credits to {member.display_name}. They now have {data[uid]['credits']} credits.")

# -------------------------------------------------------------------
# Paid commands (cost 1 credit)
# -------------------------------------------------------------------
async def check_credit(ctx):
    """Check if user has at least 1 credit; if yes, deduct and return True."""
    if not deduct_credit(ctx.author.id):
        await ctx.send("❌ You don't have enough credits. Use `.credits` to check your balance. You get 5 free credits daily.")
        return False
    return True

@bot.command(name='l')
async def log_command(ctx, *, content: str = None):
    # Credit check first
    if not await check_credit(ctx):
        return

    code_to_run = ""
    if ctx.message.attachments:
        for attachment in ctx.message.attachments:
            try:
                response = requests.get(attachment.url)
                code_to_run = response.text
                break
            except Exception as e:
                await ctx.send(f"❌ Error reading attachment: {e}")
                return
    elif content and "```" in content:
        start = content.find("```") + 3
        end = content.rfind("```")
        if start < end:
            first_line_end = content.find("\n", start)
            if first_line_end != -1 and first_line_end < end:
                lang_line = content[start:first_line_end].strip()
                if lang_line and " " not in lang_line:
                    start = first_line_end + 1
            code_to_run = content[start:end].strip()
        else:
            code_to_run = content.strip()
    elif content and content.startswith("http"):
        try:
            response = requests.get(content)
            code_to_run = response.text
        except Exception as e:
            await ctx.send(f"❌ Error fetching URL: {e}")
            return
    elif content:
        code_to_run = content.strip()
    else:
        await ctx.send("❌ Please provide code to log (as attachment, code block, URL, or plain text).")
        return
    if not code_to_run:
        await ctx.send("❌ No code found.")
        return
    try:
        user_settings = get_user_settings(ctx.author.id)  # still get for other commands
        with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as tmp:
            tmp.write(code_to_run)
            tmp_path = tmp.name
        lune_exec = "lune"
        if os.path.exists("lune.exe"):
            lune_exec = os.path.abspath("lune.exe")
        elif os.path.exists("lune"):
            lune_exec = os.path.abspath("lune")
        logger_path = os.path.join("src", "code_reconstructor_advanced.lua")
        if not os.path.exists(logger_path):
            await ctx.send("❌ Reconstructor script not found at `src/code_reconstructor.lua`.")
            return
        cmd = [lune_exec, "run", logger_path, tmp_path]
        env = os.environ.copy()
        # Force all settings to false to replicate PowerShell exactly
        for setting in DEFAULT_SETTINGS.keys():
            env[f"SETTING_{setting.upper()}"] = "0"
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env
        )
        stdout, stderr = await process.communicate()
        output = stdout.decode()
        if stderr:
            output += "\n-- STDERR --\n" + stderr.decode()
        if not output:
            output = "-- No output --"

        # Use the split-file sender
        await send_large_file(ctx, output, "reconstructed", ".lua")

        os.remove(tmp_path)
    except subprocess.TimeoutExpired:
        await ctx.send("❌ Execution timed out (30s limit).")
    except FileNotFoundError as e:
        await ctx.send(f"❌ Lune executable not found. Make sure it's installed and in PATH. Error: {e}")
    except Exception as e:
        await ctx.send(f"❌ An unexpected error occurred: {e}")

@bot.command(name='moon')
async def moon_command(ctx, *, content: str = None):
    # Credit check first
    if not await check_credit(ctx):
        return

    code_to_compile = ""
    if ctx.message.attachments:
        for attachment in ctx.message.attachments:
            try:
                response = requests.get(attachment.url)
                code_to_compile = response.text
                break
            except Exception as e:
                await ctx.send(f"❌ Error reading attachment: {e}")
                return
    elif content and "```" in content:
        start = content.find("```") + 3
        end = content.rfind("```")
        if start < end:
            first_line_end = content.find("\n", start)
            if first_line_end != -1 and first_line_end < end:
                lang_line = content[start:first_line_end].strip()
                if lang_line and " " not in lang_line:
                    start = first_line_end + 1
            code_to_compile = content[start:end].strip()
        else:
            code_to_compile = content.strip()
    elif content and content.startswith("http"):
        try:
            response = requests.get(content)
            code_to_compile = response.text
        except Exception as e:
            await ctx.send(f"❌ Error fetching URL: {e}")
            return
    elif content:
        code_to_compile = content.strip()
    else:
        await ctx.send("❌ Please provide Lua code to compile (as attachment, code block, URL, or plain text).")
        return
    if not code_to_compile:
        await ctx.send("❌ No code found.")
        return
    try:
        await ctx.defer()
        bytecode, filename = await run_moon_compile(code_to_compile)
        with BytesIO(bytecode) as file_obj:
            await ctx.send(
                content="✅ **Compilation complete!**\n"
                        "🔗 **Decompile this file online:** https://luadec.metaworm.site/",
                file=discord.File(file_obj, filename=filename)
            )
        try:
            os.remove(filename)
        except:
            pass
    except Exception as e:
        await ctx.send(f"❌ Moon compilation error: {e}")

@bot.command(name='luadump')
async def luadump_command(ctx, *, content: str = None):
    # Credit check first
    if not await check_credit(ctx):
        return

    """Universal deobfuscator – handles bytecode, MoonSec (by watermark), and generic obfuscation."""
    code_bytes = None
    code_str = None
    is_binary = False

    # Extract input
    if ctx.message.attachments:
        attachment = ctx.message.attachments[0]
        try:
            code_bytes = await attachment.read()
            if code_bytes and code_bytes[0] == 27:
                is_binary = True
            else:
                code_str = code_bytes.decode('utf-8')
        except Exception as e:
            await ctx.send(f"❌ Error reading attachment: {e}")
            return
    elif content:
        if "```" in content:
            start = content.find("```") + 3
            end = content.rfind("```")
            if start < end:
                first_line_end = content.find("\n", start)
                if first_line_end != -1 and first_line_end < end:
                    lang_line = content[start:first_line_end].strip()
                    if lang_line and " " not in lang_line:
                        start = first_line_end + 1
                code_str = content[start:end].strip()
            else:
                code_str = content.strip()
        elif content.startswith("http"):
            try:
                response = requests.get(content)
                if response.content and response.content[0] == 27:
                    code_bytes = response.content
                    is_binary = True
                else:
                    code_str = response.text
            except Exception as e:
                await ctx.send(f"❌ Error fetching URL: {e}")
                return
        else:
            code_str = content.strip()
    else:
        await ctx.send("❌ Please provide code to deobfuscate (as attachment, code block, URL, or plain text).")
        return

    if not code_bytes and not code_str:
        await ctx.send("❌ No code found.")
        return

    await ctx.defer()

    # Determine which tool to use
    if is_binary or (code_bytes and code_bytes[0] == 27):
        # Bytecode detected -> unluac
        unluac_jar = os.path.join("tools", "unluac.jar")
        if not os.path.exists(unluac_jar):
            await ctx.send(
                "❌ **unluac not found!**\n"
                "Download it from: https://sourceforge.net/projects/unluac/\n"
                "Place `unluac.jar` in a `tools/` folder next to the bot."
            )
            return
        with tempfile.NamedTemporaryFile(suffix='.luac', delete=False) as f:
            f.write(code_bytes)
            input_path = f.name
        output_path = input_path + ".lua"
        try:
            cmd = ["java", "-jar", unluac_jar, input_path]
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            if process.returncode != 0:
                error_msg = stderr.decode().strip() or stdout.decode().strip()
                await send_long_text(ctx, error_msg, "unluac_error.txt", "❌ unluac failed:\n")
                return
            deobfuscated = stdout.decode()
        finally:
            os.remove(input_path)
    else:
        # Text-based: check for MoonSec watermark (case-insensitive)
        code_text = code_str or (code_bytes.decode('utf-8') if code_bytes else "")
        # List of possible MoonSec watermarks (common variations)
        moonsec_watermarks = [
            "[Obfuscayed moonsec v3]",
            "[Obfuscated moonsec v3]",
            "Moonsec v3",
            "MoonsecV3",
        ]
        is_moonsec = any(wm.lower() in code_text.lower() for wm in moonsec_watermarks)

        if is_moonsec and os.path.exists(MOON_EXECUTABLE):
            # Use MoonSec deobfuscator
            with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as f:
                f.write(code_text)
                input_path = f.name
            output_path = input_path + ".lua"
            try:
                cmd = [MOON_EXECUTABLE, "-dev", "-i", input_path, "-o", output_path]
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await process.communicate()
                if process.returncode != 0:
                    error_msg = stderr.decode().strip() or stdout.decode().strip()
                    await send_long_text(ctx, error_msg, "moonsec_error.txt", "❌ MoonSec deobfuscator failed:\n")
                    return
                if not os.path.exists(output_path):
                    await ctx.send("❌ MoonSec deobfuscator did not create output file.")
                    return
                with open(output_path, 'r', encoding='utf-8') as f:
                    deobfuscated = f.read()
            finally:
                os.remove(input_path)
                if os.path.exists(output_path):
                    os.remove(output_path)
        else:
            # Fallback to embedded dumper.lua
            with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as f:
                f.write(DUMPER_LUA)
                dumper_path = f.name
            with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as f:
                f.write(code_text)
                input_path = f.name
            try:
                cmd = ["lua", dumper_path, input_path]
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await process.communicate()
                if process.returncode != 0:
                    error_msg = stderr.decode().strip() or stdout.decode().strip()
                    # Check if dumper detected bytecode (special message)
                    if "BYTECODE_DETECTED" in error_msg:
                        await ctx.send("⚠️ Bytecode detected – please install **unluac** in `tools/` folder to decompile it.")
                    else:
                        await send_long_text(ctx, error_msg, "dumper_error.txt", "❌ Dumper failed:\n")
                    return
                deobfuscated = stdout.decode()
            finally:
                os.remove(dumper_path)
                os.remove(input_path)

    # Send result
    if not deobfuscated.strip():
        await ctx.send("⚠️ Deobfuscator produced empty output.")
        return
    with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as out_file:
        out_file.write(deobfuscated)
        out_path = out_file.name
    await ctx.send("✅ Deobfuscated code:", file=discord.File(out_path, "deobfuscated.lua"))
    os.remove(out_path)

# -------------------------------------------------------------------
# Run bot
# -------------------------------------------------------------------
if __name__ == "__main__":
    token = os.getenv("DISCORD_TOKEN")
    if not token:
        print("❌ ERROR: DISCORD_TOKEN environment variable not set.")
        sys.exit(1)
    if not OWNER_ID:
        print("⚠️ WARNING: OWNER_ID not set. .addcredits will be disabled.")
    bot.run(token)
