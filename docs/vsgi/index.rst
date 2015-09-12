VSGI
====

VSGI is a middleware that interfaces different web server technologies under a
common and simple set of abstractions.

For the moment, it is developed along with Valum to target the needs of a web
framework, but it will eventually be extracted and distributed as a shared
library.

.. toctree::

    connection
    request
    response
    cookies
    converters
    server/index

VSGI produces process-based applications that are able to communicate with
various HTTP servers using standardized protocols.

Entry point
-----------

The entry point of a VSGI application is type-compatible with the
``ApplicationCallback`` delegate. It is a function of two arguments:
a :doc:`request` and a :doc:`response` that return a boolean indicating if the
request has been or will be processed.

::

    using VSGI;

    Server.new_with_application ("http", "org.vsgi.App", (req, res) => {
        // process the request and produce the response...
        return true;
    }).run ();

If an application indicate that the request has not been processed, it's up to
the server implementation to decide what will happen.

Error handling
~~~~~~~~~~~~~~

.. versionadded:: 0.3

At any moment, an error can be raised and handled by the server implementation
which will in turn teardown the connection appropriately.

::

    Server.new_with_application ("http", "org.vsgi.App", (req, res) => {
        throw new IOError.FAILED ("some I/O failed");
    });

Loadable application
--------------------

An application can be written as a `GLib.Module`_ served from any
implementation with ``vsgi``.

.. _GLib.Module: http://valadoc.org/#!api=gmodule-2.0/GLib.Module

.. code:: vala

    public void app (Request req, Response res) {
        res.status = 200;
        res.body.write_all ("Hello world!".dat, null);
    }

.. code-block:: bash

    vsgi [--directory=<directory>] [--server=<server>] <module_name>:<symbol> -- <arguments>

-  the directory where the shared library is located or default system path
-  server implementation which is either `soup`, `fastcgi` or `scgi`
-  the name of the library without the ``lib`` prefix and ``.so`` extension
-  an entry point symbol following the ``ApplicationCallback`` delegate as
   defined in the preceding section
-  arguments for the server implementation specified by the ``--server`` flag

.. note::

    Arguments for ``vsgi`` and those for the server implementation must be
    delemited by a ``--``. The module:symbol will become the

.. code-block:: bash

    vsgi --directory=build/examples/loader app:app -- --port=3005

If you need static initialization, GLib.Module will automatically call the
`g_module_check_init` and `g_module_unload` symbols defined in the shared
library. Implemented correctly, it will be used to perform live reloading in
a future release.

.. code:: vala

    using Gda;

    public Connection database;

    [CCode (cname = "g_module_check_init")]
    public void check_init () {
        database = Connection.from_dsn ("localhost", null, ConnectionOptions.);
    }

    [CCode (cname = "g_module_unload")]
    public void unload () {
        database.close ();
    }

    public void app (Request req, Response res) {
        // ...
    }

Asynchronous processing
~~~~~~~~~~~~~~~~~~~~~~~

The asynchronous processing model follows the `RAII pattern`_ and wraps all
resources in a connection that inherits from `GLib.IOStream`_. It is therefore
important that the said connection is kept alive as long as the streams are
being used.

.. _RAII pattern: https://en.wikipedia.org/wiki/Resource_Acquisition_Is_Initialization
.. _GLib.IOStream: http://valadoc.org/#!api=gio-2.0/GLib.IOStream

The :doc:`request` holds a reference to the said connection and the
:doc:`response` indirectly does as it holds a reference to the request.
Generally speaking, holding a reference on any of these two instances is
sufficient to keep the streams usable.

.. warning::

    As VSGI relies on reference counting to free the resources underlying
    a request, you must keep a reference to either the :doc:`request` or
    :doc:`response` during the processing, including in asynchronous callbacks.

It is important that the connection persist until all streams operations are
done as the following example demonstrates:

::

    res.body.write_async.begin ("Hello world!",
                                Priority.DEFAULT,
                                null,
                                (body, result) => {
        // the response reference will make the connection persist
        var written = res.body.write_async.end (result);
    });

