import os
import subprocess
import time
import shutil
import shlex
import concurrent.futures

FXC = "fxc.exe"

script_folder = os.path.dirname(os.path.abspath(__file__))

SHADER_COMMAND = os.path.join(script_folder, "Shader_Compile_Command_Sorted.txt")
SOURCE_FOLDER = script_folder + "\\"
COMPILE_FOLDER = os.path.join(script_folder, "COMPILED\\")


# ------------------------------------------------------------
# Parsing helpers
# ------------------------------------------------------------

def get_shader_compile_arg(cmd: str):
    fo_pos = cmd.find("/Fo")
    return cmd[4:fo_pos - 1]


def get_shader_source(cmd: str):
    start = cmd.find("\" \".\\") + 5
    return cmd[start:len(cmd) - 1]


def get_shader_dest(cmd: str):
    start = cmd.find("/Fo \"") + 7
    end = cmd.find("\" \".\\")
    return cmd[start:end]


# ------------------------------------------------------------
# Load command list
# ------------------------------------------------------------

with open(SHADER_COMMAND, "r", encoding="utf-8") as f:
    command_lines = f.read().splitlines()

last_input_path = __file__.replace(".py", ".txt")

if os.path.exists(last_input_path):
    with open(last_input_path, "r", encoding="utf-8") as f:
        last_shader_family = f.read().strip()
else:
    last_shader_family = ""

user_input = input(f"Input the name of shader family [{last_shader_family}]: ").strip()

shader_family = user_input if user_input else last_shader_family

with open(last_input_path, "w", encoding="utf-8") as f:
    f.write(shader_family + "\n")

# ------------------------------------------------------------
# Build jobs
# ------------------------------------------------------------

jobs = []
seen_lines = set()

for line in command_lines:
    if shader_family.lower() in line.lower() and line not in seen_lines:
        seen_lines.add(line)  # Mark this line as processed
        target = COMPILE_FOLDER + get_shader_dest(line)
        source = SOURCE_FOLDER + get_shader_source(line)
        compile_arg = (
                get_shader_compile_arg(line)
                + f' /D NOMAD_PLATFORM_WINDOWS /Gfa /Fo "{target}" "{source}"'
        )
        jobs.append({
            "target": target,
            "source": source,
            "compile_arg": compile_arg
        })

print(f"Found {len(jobs)} compile jobs for '{shader_family}'")

# ------------------------------------------------------------
# Remove COMPILED\engine directory
# ------------------------------------------------------------

engine_dir = os.path.join(COMPILE_FOLDER, "engine")
shutil.rmtree(engine_dir, ignore_errors=True)


# ------------------------------------------------------------
# Compile shaders
# ------------------------------------------------------------

def compile_shader(job):
    """Compile a single shader"""
    out_dir = os.path.dirname(job["target"])
    os.makedirs(out_dir, exist_ok=True)

    try:
        # Remove capture_output=True to see live output
        result = subprocess.run([FXC] + shlex.split(job["compile_arg"]),
                                shell=False)
        return result.returncode
    except Exception as e:
        print(f"Exception compiling {job['source']}: {e}")
        return -1


# Use ThreadPoolExecutor for parallel compilation
max_workers = min(32, (os.cpu_count() or 4) * 2)
print(f"Compiling {len(jobs)} shaders with {max_workers} workers...")

with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
    # Submit all jobs
    future_to_job = {executor.submit(compile_shader, job): job for job in jobs}

    # Process completed jobs
    completed = 0
    successes = 0
    failures = 0

    for future in concurrent.futures.as_completed(future_to_job):
        job = future_to_job[future]
        try:
            return_code = future.result()
            completed += 1
            if return_code == 0:
                successes += 1
            else:
                failures += 1
                print(f"FAILED: {job['source']} (return code: {return_code})")

            if completed % 10 == 0:  # Print progress every 10 shaders
                print(f"Progress: {completed}/{len(jobs)} shaders compiled ({successes} OK, {failures} failed)")

        except Exception as exc:
            print(f'{job["source"]} generated an exception: {exc}')
            completed += 1
            failures += 1

print(f"\nCompilation completed: {completed}/{len(jobs)} shaders processed")
print(f"Results: {successes} successful, {failures} failed")

# ------------------------------------------------------------
# Prepend header files
# ------------------------------------------------------------

def prepend_header(job):
    """Prepend .header file to the compiled shader output."""
    relative_path = job["target"][len(COMPILE_FOLDER):]
    header_path = os.path.join(SOURCE_FOLDER, relative_path + ".header")

    # Wait until shader file exists
    while not os.path.exists(job["target"]):
        time.sleep(0.01)

    if not os.path.exists(header_path):
        return 0  # no header, still success

    try:
        with open(header_path, "rb") as header_file:
            header_bytes = header_file.read()

        with open(job["target"], "rb") as shader_file:
            shader_bytes = shader_file.read()

        with open(job["target"], "wb") as out_file:
            out_file.write(header_bytes + shader_bytes)

        return 0
    except Exception as e:
        print(f"Header prepend failed for {job['target']}: {e}")
        return -1


print(f"Prepending headers for {len(jobs)} shaders using {max_workers} workers...")

with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
    future_to_job = {executor.submit(prepend_header, job): job for job in jobs}

    completed = 0
    ok = 0
    failed = 0

    for future in concurrent.futures.as_completed(future_to_job):
        job = future_to_job[future]
        try:
            result = future.result()
            completed += 1

            if result == 0:
                ok += 1
            else:
                failed += 1

            if completed % 20 == 0:
                print(f"Header progress: {completed}/{len(jobs)} ({ok} OK, {failed} failed)")

        except Exception as exc:
            completed += 1
            failed += 1
            print(f"Header task exception on {job['target']}: {exc}")

print(f"Header prepend finished: {ok} OK, {failed} failed")

print("All operations completed!")