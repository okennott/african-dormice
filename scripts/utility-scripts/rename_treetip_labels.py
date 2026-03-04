from ete3 import Tree

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

def detect_and_load_tree(tree_file):
    """
    Tries to load the tree in both Newick and Nexus formats, detecting the format.
    
    Parameters:
    - tree_file: The path to the tree file.
    
    Returns:
    - A Tree object if successful, otherwise raises an error.
    """
    try:
        # First, try loading the tree as Newick
        print(f"Trying to load the tree as Newick format: {tree_file}")
        tree = Tree(tree_file, format=1)  # Newick format
        return tree
    except:
        print(f"Failed to load as Newick, trying Nexus format.")
        try:
            # If Newick fails, try loading as Nexus
            tree = Tree(tree_file, format=2)  # Nexus format
            return tree
        except:
            raise ValueError(f"Failed to load the tree. Unsupported format for file: {tree_file}")

def batch_rename_tree(input_tree_file, output_tree_file, renaming_file):
    """
    Batch renames the tip labels of a phylogenetic tree using a renaming file.
    
    Parameters:
    - input_tree_file: Path to the input tree file (in Newick or Nexus format).
    - output_tree_file: Path to save the renamed tree.
    - renaming_file: Path to the TXT file containing old and new names.
    """
    # Load the renaming scheme
    renaming_scheme = load_renaming_scheme(renaming_file)
    
    # Detect and load the tree in the appropriate format
    tree = detect_and_load_tree(input_tree_file)
    
    # Rename the tip labels based on the renaming scheme
    for leaf in tree:
        if leaf.name in renaming_scheme:
            leaf.name = renaming_scheme[leaf.name]
    
    # Save the renamed tree to a new file
    tree.write(outfile=output_tree_file)
    print(f"Renamed tree saved to {output_tree_file}")

# Hard-coded input/output filenames and renaming file
input_tree_file = "mafft-nexus-internal-trimmed-gblocks-clean-75p-phylip.phylip.treefile"
output_tree_file = "mafft-nexus-internal-trimmed-gblocks-clean-75p-phylip.phylip_RenamedTips.treefile"
renaming_file = "BatchRenameAlignmentSequences.txt"

# Call the function to rename the tree tips
batch_rename_tree(input_tree_file, output_tree_file, renaming_file)
