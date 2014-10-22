(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt

module Log = Log.Make(struct let section = "TAG" end)

module type S = sig
  include Sig.Uid
  val master: t
end

module String = struct
  include Tc.S
  let compute_from_cstruct b = Cstruct.to_string b
  let compute_from_string r = r
  let pretty t = t
  let of_raw s = s
  let to_raw s = s
  let master = "master"

  let implode ts =
    String.concat "/" ts

  let explode t =
    List.filter ((<>)"") (Stringext.split t ~on:'/')

  let to_json t =
    Ezjsonm.list Ezjsonm.string (explode t)

  let of_json j =
    implode (Ezjsonm.get_list Ezjsonm.get_string j)

end

module type STORE = sig
  include Sig.RW
  module Key: S with type t = key
  module Value: Sig.Uid with type t = value
end

module Make
    (K: S)
    (V: Sig.Uid)
    (S: Sig.RW with type key = K.t and type value = V.t)
= struct

  module Key = K

  module Value = V

  include S

  let list t _ =
    dump t >>= fun l ->
    return (List.map fst l)

end
