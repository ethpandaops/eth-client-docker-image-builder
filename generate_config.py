#!/usr/bin/env python3

import yaml
import os
import sys

# Default repository mapping for known clients
DEFAULT_REPOS = {
    'besu': 'hyperledger/besu',
    'erigon': 'erigontech/erigon',
    'ethereumjs': 'ethereumjs/ethereumjs-monorepo',
    'ethrex': 'lambdaclass/ethrex',
    'geth': 'ethereum/go-ethereum',
    'lighthouse': 'sigp/lighthouse',
    'nimbus-eth2': 'status-im/nimbus-eth2',
    'nimbus-validator-client': 'status-im/nimbus-eth2',
    'nimbus-eth1': 'status-im/nimbus-eth1',
    'prysm-beacon-chain': 'offchainlabs/prysm',
    'prysm-validator': 'offchainlabs/prysm',
    'teku': 'consensys/teku',
    'lodestar': 'chainsafe/lodestar',
    'reth': 'paradigmxyz/reth',
    'nethermind': 'nethermindeth/nethermind',
    'eleel': 'sigp/eleel',
    'dummy-el': 'ethpandaops/dummy-el',
    'grandine': 'grandinetech/grandine',
    'flashbots-builder': 'flashbots/builder',
    'tx-fuzz': 'MariusVanDerWijden/tx-fuzz',
    'goomy-blob': 'ethpandaops/goomy-blob',
    'ethereum-genesis-generator': 'ethpandaops/ethereum-genesis-generator',
    'mev-rs': 'ralexstokes/mev-rs',
    'reth-rbuilder': 'flashbots/rbuilder',
    'rustic-builder': 'pawanjay176/rustic-builder',
    'mev-boost': 'flashbots/mev-boost',
    'mev-boost-relay': 'flashbots/mev-boost-relay',
    'goevmlab': 'holiman/goevmlab',
    'eth-das-guardian': 'probe-lab/eth-das-guardian',
    'syncoor': 'ethpandaops/syncoor',
    'zeam': 'blockblaz/zeam',
    'ream': 'ReamLabs/ream',
    'consensoor': 'ethpandaops/consensoor',
    'meth': 'ethereum/go-ethereum',
    'nevermind': 'nethermindeth/nethermind',
    # Add more defaults as needed
}

# Build argument defaults for special cases
BUILD_ARGS = {
    'mev-rs/main-minimal': 'FEATURES=minimal-preset',
    'reth-rbuilder/develop': 'RBUILDER_BIN=reth-rbuilder'
}

# Clients that need to have minimal builds created automatically
MINIMAL_VARIANTS = [
    'grandine',
    'mev-rs',
    'prysm-beacon-chain',
    'prysm-validator',
    'nimbus-eth2',
    'nimbus-validator-client'
]

# Clients that need to have sentry builds created automatically
SENTRY_VARIANTS = [
    'lighthouse',
    'nimbus-eth2'
]

# Clients that need to have xatu sidecar builds created automatically
SIDECAR_VARIANTS = [
    'lighthouse',
    'teku'
]

def generate_config():
    # Read the simplified branches configuration
    with open('branches.yaml', 'r') as f:
        branches_config = yaml.safe_load(f)

    # Expand combined client definitions
    expanded_config = {}
    for client_name, client_config in branches_config.items():
        if client_name == 'prysm':
            # Expand prysm into both beacon and validator
            expanded_config['prysm-beacon-chain'] = client_config
            expanded_config['prysm-validator'] = client_config
        elif client_name == 'nimbus':
            # Expand nimbus into both eth2 and validator
            expanded_config['nimbus-eth2'] = client_config
            expanded_config['nimbus-validator-client'] = client_config
        else:
            # Keep as-is
            expanded_config[client_name] = client_config

    branches_config = expanded_config

    # Output configuration list
    config_list = []

    # Process each client
    for client_name, client_config in branches_config.items():
        # Skip commented out clients
        if client_name.startswith('#'):
            continue

        # Get default repository for this client
        default_repo = DEFAULT_REPOS.get(client_name, f"ethpandaops/{client_name}")

        # Process main branches
        if 'branches' in client_config:
            for branch_spec in client_config['branches']:
                # Check if this is a branch with special tag
                if '@' in branch_spec:
                    branch, special_tag = branch_spec.split('@', 1)
                    process_branch(client_name, default_repo, branch, special_tag, config_list)
                else:
                    # Regular branch
                    # Replace any slashes in branch name with hyphens for the tag
                    safe_branch_name = branch_spec.replace('/', '-')
                    process_branch(client_name, default_repo, branch_spec, safe_branch_name, config_list)

                    # Auto-generate minimal builds if needed
                    if client_name in MINIMAL_VARIANTS:
                        process_branch(client_name, default_repo, branch_spec, f"{safe_branch_name}-minimal", config_list)

                    # Auto-generate sentry builds if needed
                    if client_name in SENTRY_VARIANTS:
                        if branch_spec == 'stable':
                            process_branch(client_name, default_repo, branch_spec, "xatu-sentry", config_list)
                        elif branch_spec == 'unstable':
                            process_branch(client_name, default_repo, branch_spec, "xatu-sentry-unstable", config_list)

                    # Auto-generate xatu sidecar builds if needed
                    if client_name in SIDECAR_VARIANTS:
                        if branch_spec == 'unstable':
                            process_branch(client_name, default_repo, branch_spec, "xatu-sidecar-unstable", config_list)
                        elif 'devnet' in branch_spec:
                            # For devnet branches, append -xatu-sidecar to the safe branch name
                            process_branch(client_name, default_repo, branch_spec, f"{safe_branch_name}-xatu-sidecar", config_list)
                        # Teku uses master as its main development branch (equivalent to unstable)
                        elif client_name == 'teku' and branch_spec == 'master':
                            process_branch(client_name, default_repo, branch_spec, "xatu-sidecar-master", config_list)

        # Process alternate repositories if they exist
        if 'alt_repos' in client_config:
            for alt_repo, branches in client_config['alt_repos'].items():
                # Extract the first part of the repo name for the tag prefix
                repo_parts = alt_repo.split('/')
                prefix = repo_parts[0].lower()

                for branch_spec in branches:
                    # Check if this is a branch with special tag
                    if '@' in branch_spec:
                        branch, special_tag = branch_spec.split('@', 1)
                        # Create the target tag with prefix and special tag
                        target_tag = f"{prefix}-{special_tag}"
                        process_branch(client_name, alt_repo, branch, target_tag, config_list)
                    else:
                        # Regular branch with prefix
                        # Replace any slashes in branch name with hyphens for the tag
                        safe_branch_name = branch_spec.replace('/', '-')
                        target_tag = f"{prefix}-{safe_branch_name}"
                        process_branch(client_name, alt_repo, branch_spec, target_tag, config_list)

                        # Auto-generate minimal builds for alt repos too
                        if client_name in MINIMAL_VARIANTS:
                            process_branch(client_name, alt_repo, branch_spec, f"{prefix}-{safe_branch_name}-minimal", config_list)

        # Process custom configurations if they exist
        if 'custom_configs' in client_config:
            for custom_config in client_config['custom_configs']:
                # Extract required fields
                name = custom_config['name']
                ref = custom_config['ref']
                tag = custom_config['tag']
                
                # Optional source_patch field
                source_patch = custom_config.get('source_patch')
                
                # Use default repository for custom configs
                process_branch_custom(client_name, default_repo, ref, tag, config_list, source_patch)

    # Sort configs by client name for better readability
    config_list.sort(key=lambda x: extract_client_name(x))

    # Group items by client name
    client_groups = {}
    for config in config_list:
        client_name = extract_client_name(config)
        if client_name not in client_groups:
            client_groups[client_name] = []
        client_groups[client_name].append(config)

    # Write the generated config to config.yaml with fancy headers
    with open('config.yaml', 'w') as f:
        f.write('# AUTOMATICALLY GENERATED - DO NOT EDIT DIRECTLY\n')
        f.write('# Edit branches.yaml and run generate_config.py instead\n\n')

        first_client = True
        for client_name, configs in client_groups.items():
            if not first_client:
                f.write('\n')  # Add extra space between client sections
            else:
                first_client = False

            # Create fancy header with client name
            header = f"{'#' * (len(client_name) + 8)}\n"  # Top row of #
            header += f"# {client_name} #\n"              # Client name with # on sides
            header += f"{'#' * (len(client_name) + 8)}"   # Bottom row of #
            f.write(header + '\n')

            # Dump the configs for this client
            for config in configs:
                f.write('- ')
                yaml_str = yaml.dump(config, default_flow_style=False)
                # Indent all lines except the first
                indented_yaml = yaml_str.replace('\n', '\n  ').rstrip()
                f.write(indented_yaml + '\n')

    print(f"Generated config.yaml with {len(config_list)} configurations")

def extract_client_name(config):
    """Extract the client name from a config"""
    return config['target']['repository'].split('/')[1]

def get_dockerfile_path(client_name, target_tag=None):
    """Determine the dockerfile path based on client name and tag conventions"""
    # Special cases for different clients
    if client_name == 'reth-rbuilder':
        return f"./{client_name}/Dockerfile.rbuilder"
    elif client_name == 'nimbus-eth2':
        if target_tag and 'minimal' in target_tag:
            return f"./{client_name}/Dockerfile.beacon-minimal"
        return f"./{client_name}/Dockerfile.beacon"
    elif client_name == 'nimbus-validator-client':
        if target_tag and 'minimal' in target_tag:
            return f"./{client_name.replace('-validator-client', '-eth2')}/Dockerfile.validator-minimal"
        return f"./{client_name.replace('-validator-client', '-eth2')}/Dockerfile.validator"
    elif client_name == 'prysm-beacon-chain':
        return f"./prysm/Dockerfile.beacon"
    elif client_name == 'prysm-validator':
        return f"./prysm/Dockerfile.validator"
    elif client_name == 'grandine':
        if target_tag and 'minimal' in target_tag:
            return f"./{client_name}/Dockerfile.minimal"
        return f"./{client_name}/Dockerfile"

    # Base path is usually the client directory with a Dockerfile
    default_path = f"./{client_name}/Dockerfile"

    # Check if the directory and file exists
    if os.path.exists(default_path):
        return default_path

    return None

def get_build_script(client_name, branch, target_tag=None):
    """Determine the build script path based on client name and tag conventions"""
    # Standard build script location
    standard_script = f"./{client_name}/build.sh"

    # Special cases for different clients
    if client_name == 'lighthouse' and target_tag and 'xatu-sentry' in target_tag:
        return f"./{client_name}/xatu-sentry.sh"
    elif client_name == 'nimbus-eth2' and target_tag and 'xatu-sentry' in target_tag:
        return f"./{client_name}/xatu-sentry.sh"
    elif client_name == 'lighthouse' and target_tag and 'xatu-sidecar' in target_tag:
        return f"./{client_name}/xatu-sidecar.sh"
    elif client_name == 'teku' and target_tag and 'xatu-sidecar' in target_tag:
        return f"./{client_name}/xatu-sidecar.sh"
    elif client_name == 'besu':
        return "./besu/build.sh"
    elif client_name == 'lodestar':
        return f"./{client_name}/build.sh"
    elif client_name == 'prysm-beacon-chain':
        if target_tag and 'minimal' in target_tag:
            return f"./prysm/build_beacon_minimal.sh"
        return f"./prysm/build_beacon.sh"
    elif client_name == 'prysm-validator':
        if target_tag and 'minimal' in target_tag:
            return f"./prysm/build_validator_minimal.sh"
        return f"./prysm/build_validator.sh"
    elif client_name == 'grandine':
        return f"./{client_name}/build.sh"

    # Check if the standard script exists
    if os.path.exists(standard_script):
        return standard_script

    return None

def get_build_args(client_name, source_repo, branch, target_tag):
    """Determine the build arguments based on conventions"""
    # Check for known build args based on client/repo/tag combinations
    key_full = f"{source_repo}/{target_tag}"
    key_repo_branch = f"{source_repo}/{branch}"
    key_client_tag = f"{client_name}/{target_tag}"

    if key_full in BUILD_ARGS:
        return BUILD_ARGS[key_full]
    elif key_repo_branch in BUILD_ARGS:
        return BUILD_ARGS[key_repo_branch]
    elif key_client_tag in BUILD_ARGS:
        return BUILD_ARGS[key_client_tag]

    # Special cases
    if client_name == 'mev-rs' and 'minimal' in target_tag:
        return 'FEATURES=minimal-preset'
    elif client_name == 'reth-rbuilder':
        return 'RBUILDER_BIN=reth-rbuilder'

    return None

def process_branch(client_name, source_repo, branch, target_tag, config_list):
    """Process a single branch configuration"""
    # Create the basic configuration
    config = {
        'source': {
            'repository': source_repo,
            'ref': branch
        },
        'target': {
            'tag': target_tag,
            'repository': f'ethpandaops/{client_name}'
        }
    }

    # Add dockerfile if one exists for this client
    dockerfile_path = get_dockerfile_path(client_name, target_tag)
    if dockerfile_path:
        config['target']['dockerfile'] = dockerfile_path

    # Add build script if one exists for this client/branch combination
    build_script = get_build_script(client_name, branch, target_tag)
    if build_script:
        config['build_script'] = build_script

    # Add build args if needed
    build_args = get_build_args(client_name, source_repo, branch, target_tag)
    if build_args:
        config['build_args'] = build_args

    config_list.append(config)

def process_branch_custom(client_name, source_repo, branch, target_tag, config_list, source_patch=None):
    """Process a single custom branch configuration with optional patch"""
    # Create the basic configuration
    config = {
        'source': {
            'repository': source_repo,
            'ref': branch
        },
        'target': {
            'tag': target_tag,
            'repository': f'ethpandaops/{client_name}'
        }
    }
    
    # Add source patch if specified
    if source_patch:
        config['source']['patch'] = source_patch
    
    # Add dockerfile if one exists for this client
    dockerfile_path = get_dockerfile_path(client_name, target_tag)
    if dockerfile_path:
        config['target']['dockerfile'] = dockerfile_path
    # Add build script if one exists for this client/branch combination
    build_script = get_build_script(client_name, branch, target_tag)
    if build_script:
        config['build_script'] = build_script
    # Add build args if needed
    build_args = get_build_args(client_name, source_repo, branch, target_tag)
    if build_args:
        config['build_args'] = build_args
    config_list.append(config)

if __name__ == '__main__':
    if not os.path.exists('branches.yaml'):
        print("Error: branches.yaml not found. Please create it first.")
        sys.exit(1)

    generate_config()