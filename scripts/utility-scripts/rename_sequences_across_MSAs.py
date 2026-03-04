import os
from Bio import SeqIO
from Bio.SeqIO import parse

def load_renaming_scheme(renaming_file):
    """
    Loads the renaming scheme from a TXT file with 'old name' and 'new name' columns.
    
    Parameters:
    - renaming_file: Path to the TXT file containing the renaming scheme.
    
    Returns:
    - A dictionary mapping old names to new names.
    """
    renaming_dict = {}
    
    with open(renaming_file, "r") as file:
        for line in file:
            # Split the line by tab ('\t') and ignore lines that don't have exactly 2 entries
            parts = line.strip().split('\t')
            if len(parts) == 2:
                old_name, new_name = parts
                renaming_dict[old_name] = new_name
            else:
                print(f"Skipping malformed line: {line.strip()}")
    
    return renaming_dict

def detect_format(input_file):
    """
    Detects the alignment format based on the file extension or content.
    
    Parameters:
    - input_file: The path to the input alignment file.
    
    Returns:
    - The format (fasta, phylip, or nexus).
    """
    ext = os.path.splitext(input_file)[1].lower()
    
    if ext in ['.fas', '.fasta']:
        return "fasta"
    elif ext in ['.phy', '.phylip']:
        return "phylip"
    elif ext in ['.nex', '.nexus']:
        return "nexus"
    else:
        # Fallback: Check the file content for format clues (optional improvement)
        with open(input_file, "r") as file:
            first_line = file.readline().strip()
            if first_line.startswith("#NEXUS"):
                return "nexus"
            elif first_line.startswith(">"):
                return "fasta"
            else:
                raise ValueError(f"Could not determine format of file: {input_file}")

def batch_rename_sequences(input_file, output_file, renaming_scheme):
    """
    Batch renames sequences in an alignment using a renaming scheme.
    
    Parameters:
    - input_file: The path to the input alignment file.
    - output_file: The path where the renamed sequences will be written.
    - renaming_scheme: A dictionary with old and new names.
    """
    # Detect the format automatically
    file_format = detect_format(input_file)
    
    # Read the sequences from the input file
    records = list(SeqIO.parse(input_file, file_format))
    
    # Rename the sequences based on the renaming scheme
    renamed_records = []
    
    for record in records:
        old_id = record.id
        
        # Rename based on the scheme, if the old ID is found in the scheme
        if old_id in renaming_scheme:
            new_id = renaming_scheme[old_id]
        else:
            new_id = old_id  # Keep the original name if no mapping is found
        
        record.id = new_id
        record.description = ""  # Remove description to avoid issues in certain formats
        renamed_records.append(record)
    
    # Write the renamed sequences to the output file
    with open(output_file, "w") as output_handle:
        SeqIO.write(renamed_records, output_handle, file_format)
    
    print(f"Renamed sequences saved to {output_file}")

def rename_sequences_in_directory(input_dir, output_dir, renaming_file):
    """
    Renames sequences in all alignment files within a directory using the same renaming scheme.
    
    Parameters:
    - input_dir: The directory containing the alignment files to be renamed.
    - output_dir: The directory where the renamed alignment files will be saved.
    - renaming_file: The path to the TXT file containing old and new names.
    """
    # Load the renaming scheme from the file
    renaming_scheme = load_renaming_scheme(renaming_file)
    
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Iterate over all files in the input directory
    for filename in os.listdir(input_dir):
        input_file = os.path.join(input_dir, filename)
        output_file = os.path.join(output_dir, filename)
        
        try:
            print(f"Renaming sequences in file: {filename}")
            batch_rename_sequences(input_file, output_file, renaming_scheme)
        except ValueError as e:
            print(f"Skipping file {filename}: {e}")
    
    print(f"Renaming completed for all files in {input_dir}")

# Example usage
input_dir = "6_seq_aligned_trimmed_cleannames_95p"  # Directory containing the alignment files
output_dir = "6_seq_aligned_trimmed_cleannames_95p.voucherIDs"  # Directory to save renamed files
renaming_file = "RenameSequencesInMultipleAlignments_namingfile.txt"

# Call the function to batch rename sequences for all alignment files in the directory
rename_sequences_in_directory(input_dir, output_dir, renaming_file)
