# Collectd with All Plugins

This is a python script to create a Dockerfile that installs all of our
publically available collectd plugins into the Ubuntu-based collectd image.
The plugins are specified in the `plugins.yaml` file.  They all get installed
to `/usr/share/collectd/<plugin_name>`, instead of going all over the
filesystem.

You can specify extra install steps if necessary by adding a
`extra_instructions` key to a plugin config object.  The value should be an
array of instructions which will be run in the Dockerfile in the same `RUN`
command as the rest of the installation for that plugin.

Additional apt packages can be installed with the key `apt_packages`, and
additional pip packages with the `pip_packages` key.  These both take arrays of
package names.

This does not do any configuration, it just installs the plugins without any
configuration.
