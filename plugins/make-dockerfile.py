#!/usr/bin/env python

from __future__ import print_function

import yaml
import os
import sys
import requests

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

TEMPLATE = """
FROM quay.io/signalfuse/collectd

RUN apt-get update -q &&\\
    apt-get install -y -q git {extra_apt_packages} &&\\
    apt-get clean

{plugin_install_steps}
""".strip()

LABEL = """LABEL com.signalfx.plugin.{plugin_name}.version="{plugin_version}" """.strip()

GIT_CLONE = """
git clone --branch {tag} --depth 1 --single-branch https://github.com/{repo_name}.git /usr/share/collectd/{plugin_name} &&\\
    rm -rf /usr/share/collectd/{plugin_name}/.git
""".strip()

PIP_INSTALL = """pip install {}"""

RUN = """RUN {}"""

def to_stderr(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def read_plugin_list(config_path):
    with open(config_path, 'r') as f:
        return yaml.load(f)

def get_latest_release_from_github(repo):
    resp = requests.get("https://api.github.com/repos/{}/releases/latest".format(repo))
    if resp.status_code == 404:
        return None

    return resp.json()

def get_release_from_github(repo, tag):
    resp = requests.get("https://api.github.com/repos/{}/releases/tags/{}".format(repo, tag))
    resp.raise_for_status()

    return resp.json()

def get_commit_hash_for_branch(branch, repo):
    resp = requests.get("https://api.github.com/repos/{}/branches/master".format(repo))

    return resp.json()['commit']['sha']

def docker_commands_for_plugin(plugin):
    if plugin['version'] == "latest":
        release = get_latest_release_from_github(plugin['repo'])
        if release:
            tag_name = version = release['tag_name']
        if not release:
            # This is subject to a race condition if the image is built after
            # master changes.  The commit hash would no longer be accurate.  It
            # is much better to do releases and have named tags.
            tag_name = 'master'
            version = get_commit_hash_for_branch('master', plugin['repo'])
    else:
        release = get_release_from_github(plugin['repo'], plugin['version'])

    lines = []
    lines.append(GIT_CLONE.format(tag=tag_name,
                                  repo_name=plugin['repo'],
                                  plugin_name=plugin['name']))

    if 'pip_packages' in plugin:
        lines.append(PIP_INSTALL.format(' '.join(plugin['pip_packages'])))

    if 'extra_instructions' in plugin:
        lines.extend(plugin['extra_instructions'])

    run = RUN.format(" &&\\\n    ".join(lines))

    label = LABEL.format(plugin_name=plugin['name'],
                         plugin_version=version.lstrip('v'))

    return run + "\n" + label

def make_dockerfile(plugin_config_path):
    extra_apt_packages = []
    plugin_install_steps = []

    for plugin in read_plugin_list(plugin_config_path):
        extra_apt_packages.extend(plugin.get('apt_packages', []))
        plugin_install_steps.append(docker_commands_for_plugin(plugin))

    return TEMPLATE.format(extra_apt_packages=" ".join(extra_apt_packages),
                           plugin_install_steps="\n\n".join(plugin_install_steps))


if __name__ == "__main__":
    print(make_dockerfile(os.path.join(SCRIPT_DIR, "plugins.yaml")))
