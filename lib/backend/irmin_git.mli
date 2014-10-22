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

(** Serialize the irminsule objects to a local Git store. *)

module type Config = sig

  val root: string option
  (** Database root. *)

  module Store: Git.Store.S
  (** Git database implementation. Can be [Git_fs] or [Git_memory]. *)

  module Sync: Git.Sync.S with type t = Store.t
  (** Synchronisation engine. *)

  val bare: bool
  (** Should we extend the filesystem *)

  val disk: bool
  (** Enable disk operations such as installing watches and limiting
      concurrent open files. Should be consistent with the [Store]
      implementation. *)

end

module Memory: Irmin.Sig.BACKEND
(** In-memory Git store (using [Git.Memory]). *)

module Memory' (C: sig val root: string end): Irmin.Sig.BACKEND
(** Create a in-memory store with a given root path -- stores with
    different roots will not share their contents. *)

module Make (C: Config): Irmin.Sig.BACKEND
(** Git backend. *)

module Sync (B: Irmin.Sig.BACKEND): Irmin.Sync.STORE
(** Fast synchronisation using the Git protocol. *)
