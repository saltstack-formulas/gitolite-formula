include:
  - git
  - perl

{% from "gitolite/defaults.jinja" import gitolite with context %}

{% for user in gitolite.users %}

# variables
{% set shell = user.shell if user.shell is defined else gitolite.shell %}
{% set home = user.home if user.home is defined else gitolite.home + '/' + user.username %}
{% set ssh_pubkey = user.ssh_pubkey if user.ssh_pubkey is defined else gitolite.ssh_pubkey %}

{{ user.username }}:
  user.present:
    - shell: {{ shell }}
    - home: {{ home }}

{{ home }}/.ssh:
  file.directory:
    - user: {{ user.username }}
    - mode: 700
    - require:
      - user: {{ user.username }}

{{ home }}/bin:
  file.directory:
    - user: {{ user.username }}
    - mode: 755
    - require:
      - user: {{ user.username }}

{{ home }}/gitolite:
  git.latest:
    - name: {{ gitolite.repository_url }}
    - rev: {{ gitolite.revision }}
    - user: {{ user.username }}
    - target: {{ home }}/gitolite
    - require:
      - user: {{ user.username }}

{{ home }}/gitolite-admin.pub:
  file.managed:
    - contents: {{ ssh_pubkey }}
    - user: {{ user.username }}

install_gitolite_{{ user.username }}:
  cmd.run:
    - name: {{ home }}/gitolite/install -ln {{ home }}/bin
    - user: {{ user.username }}
    - cwd: {{ home }}
    - require:
      - git: {{ home }}/gitolite
      - file: {{ home }}/bin

setup_gitolite_{{ user.username }}:
  cmd.run:
    - name: {{ home }}/gitolite/src/gitolite setup -pk {{ home }}/gitolite-admin.pub
    - user: {{ user.username }}
    - cwd: {{ home }}
    - env:
      - HOME: {{ home }}
    - require:
      - cmd: install_gitolite_{{ user.username }}
      - file: {{ home }}/gitolite-admin.pub
{% endfor %}
