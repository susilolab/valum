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

using GLib;
using VSGI;

/**
 * Utilities and middlewares to process multipart message.
 *
 * @since 0.3
 */
[CCode (gir_namespace = "ValumMultipart", gir_version = "0.3")]
namespace Valum.Multipart {

	/**
	 * Invoked for each part of a multipart message.
	 *
	 * @since 0.3
	 */
	public delegate void PartCallback (Soup.MessageHeaders part_headers, InputStream part) throws Error;

	/**
	 * Invoked when a form has been fully read.
	 *
	 * @since 0.3
	 */
	public delegate void FormCallback (HashTable<string, string> data) throws Error;

	/**
	 * Parse a typical multipart message, invoking the provided callback on each
	 * part.
	 *
	 * If the request is not a multipart message, a {@link Valum.ClientError.UNSUPPORTED_MEDIA_TYPE}
	 * will be raised.
	 *
	 * If a 'boundary' is missing, a {@link Valum.ClientError.BAD_REQUEST} will
	 * be raised.
	 *
	 * Once all parts has been processed, the control flow will be passed with
	 * to the following handler and the epilogue may be read as it remain
	 * unconsumed in the body stream.
	 *
	 * If cancelled, the request body will be left in an undefined state.
	 *
	 * @since 0.3
	 *
	 * @param forward     invoked on each encountered part
	 * @param cancellable
	 */
	public HandlerCallback parse_multipart (owned PartCallback forward, Cancellable? cancellable = null) {
		return (req, res, next) => {
			HashTable<string, string> @params;
			if (!req.headers.get_content_type (out @params).has_prefix ("multipart/")) {
				throw new ClientError.UNSUPPORTED_MEDIA_TYPE ("Only 'multipart/*' messages are considered acceptable.");
			}

			if (@params["boundary"] == null) {
				throw new ClientError.BAD_REQUEST ("The 'boundary' parameter in the 'Content-Type' header is mandatory.");
			}

			var stream = new MultipartInputStream (req.body, @params["boundary"]);

			Soup.MessageHeaders part_headers;
			InputStream? part;
			while ((part = stream.next_part (out part_headers, cancellable)) != null) {
				forward (part_headers, part);
			}

			return next ();
		};
	}

	/**
	 * Parse a 'mulipart/form-data' message according to RFC2388.
	 *
	 * The basic parsing is performed by {@link Valum.Multipart.parse_multipart}.
	 * Parts which specify the 'form-data' disposition will be processed and
	 * passed to the 'form' callback. Other parts will be passed to the 'part'
	 * callback.
	 *
	 * @see Valum.Multipart.parse_multipart
	 *
	 * @since 0.3
	 *
	 * @param form    invoked when the form has been fully consumed
	 * @param forward invoked on parts which 'Content-Disposition' is not
	 *                'form-data'
	 */
	public HandlerCallback parse_form_data (FormCallback form, PartCallback forward, Cancellable? cancellable = null) {
		return parse_multipart ((part_headers, part) => {
			var data = new HashTable<string, string> (str_hash, str_equal);

			string disposition;
			HashTable<string, string> @params;
			part_headers.get_content_disposition (out disposition, out @params);

			// file
			if ("filename" in @params) {
				forward (part_headers, part);
			}

			// form data
			else if ("text/plain" == part_headers.get_content_type (null)) {
				var buffer = new uint8[part_headers.get_content_length ()];

				size_t bytes_read;
				part.read_all (buffer, out bytes_read, cancellable);

				// convert to 'UTF-8'
				size_t bytes_written;
				data[@params["name"]] = GLib.convert ((string) buffer,
				                                      buffer.length,
				                                      "utf-8",
				                                      @params["charset"] ?? "iso-8859-1",
				                                      out bytes_read,
				                                      out bytes_written);
			}

			// anonymous file
			else {
				forward (part_headers, part);
			}

			form (data);
		}, cancellable);
	}
}
