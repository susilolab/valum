/*
 * This file is part of Valum.
 *
 * Valum is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Valum is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Valum.  If not, see <http://www.gnu.org/licenses/>.
 */

using Valum;
using VSGI;

public Router? _app = null;

[CCode (cname = "g_module_check_init")]
public void init () {
	_app = new Router ();

	_app.get ("/", (req, res) => {
		return res.expand_utf8 ("Hello world!");
	});
}

[CCode (cname = "g_module_unload")]
public void unload () {
	_app = null;
}

/**
 * Entry point
 */
public bool app (Request req, Response res) throws Error {
	return _app.handle (req, res);
}
