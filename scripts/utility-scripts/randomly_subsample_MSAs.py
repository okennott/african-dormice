import os
import random
import shutil
import argparse

def main():
    parser = argparse.ArgumentParser(
        description="Randomly copy a proportion of files from one folder to another."
    )
    parser.add_argument('--input', required=True, help='Path to the input/source folder')
    parser.add_argument('--output', required=True, help='Path to the output/destination folder')
    parser.add_argument('--proportion', type=float, default=0.10,
                        help='Proportion of files to copy (0-1), default 0.10')
    args = parser.parse_args()

    source_folder = args.input
    destination_folder = args.output
    proportion = args.proportion

    # Validate proportion
    if not (0 < proportion <= 1):
        print("Error: --proportion must be between 0 and 1 (e.g., 0.1 for 10%)")
        return

    # Ensure destination folder exists
    os.makedirs(destination_folder, exist_ok=True)

    # Get list of files (non-recursive)
    files = [f for f in os.listdir(source_folder)
             if os.path.isfile(os.path.join(source_folder, f))]

    if not files:
        print(f"No files found in {source_folder}. Nothing to copy.")
        return

    num_files_to_copy = max(1, int(len(files) * proportion))
    selected_files = random.sample(files, num_files_to_copy)

    copied_files = []
    for file in selected_files:
        src = os.path.join(source_folder, file)
        dst = os.path.join(destination_folder, file)
        if os.path.exists(dst):
            print(f"Skipping {file}: already exists in destination.")
            continue
        shutil.copy2(src, dst)  # preserve metadata
        copied_files.append(file)

    print(f"Copied {len(copied_files)} files from {source_folder} to {destination_folder}:")
    for f in copied_files:
        print(f"  - {f}")

if __name__ == "__main__":
    main()
