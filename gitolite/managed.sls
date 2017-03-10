{% from "gitolite/defaults.jinja" import gitolite with context %}
{% from "gitolite/defaults.jinja" import get_home %}
{% from "gitolite/defaults.jinja" import get_shell %}

include:
  - gitolite

{% for user in gitolite.users %}
{% set home = get_home(user, gitolite) %}
{% set shell = get_shell(user, gitolite) %}
{% set admin_home = "{}-admin".format(home) %}
{% set admin_username = "{}-admin".format(user.username) %}

{{ user.username }}_admin_user:
  user.present:
    - name: {{ admin_username }}
    - shell: {{ shell }}
    - home: {{ admin_home }}

{{ admin_home }}/.ssh:
  file.directory:
    - user: {{ admin_username }}
    - mode: 700
    - require:
      - user: {{ user.username }}_admin_user

generate_{{ user.username }}_admin_key:
  cmd.run:  
    - name: "ssh-keygen -t rsa -N '' -f {{ admin_home }}/.ssh/id_rsa"
    - user: {{ admin_username }}
    - creates: {{ admin_home }}/.ssh/id_rsa.pub
    - require:
      - file: {{ admin_home }}/.ssh
      - user: {{ user.username }}_admin_user
    - require_in:
      - file: {{ home }}/gitolite-admin.pub

extend:
  {{ home }}/gitolite-admin.pub:
    file.copy:
      - force: True
      - source: {{ admin_home }}/.ssh/id_rsa.pub
      - onchanges:
        - cmd: generate_{{ user.username }}_admin_key
{% endfor %}
