import gleam/dynamic.{type DecodeError, type Dynamic, DecodeError} as dyn
import gleam/map.{type Map}
import gleam/option.{type Option, None}
import gleam/function
import gleam/result
import birl/time.{type DateTime}

/// Information on a package from Hex's `/api/packages` endpoint.
pub type Package {
  Package(
    name: String,
    html_url: Option(String),
    docs_html_url: Option(String),
    meta: PackageMeta,
    downloads: Map(String, Int),
    owners: Option(List(PackageOwner)),
    releases: List(PackageRelease),
    inserted_at: DateTime,
    updated_at: DateTime,
  )
}

pub type PackageMeta {
  PackageMeta(
    links: Map(String, String),
    licenses: List(String),
    description: Option(String),
  )
}

pub type PackageRelease {
  PackageRelease(version: String, url: String, inserted_at: DateTime)
}

pub type PackageOwner {
  PackageOwner(username: String, email: Option(String), url: String)
}

pub fn decode_package(data: Dynamic) -> Result(Package, List(DecodeError)) {
  dyn.decode9(
    Package,
    dyn.field("name", dyn.string),
    dyn.field("html_url", dyn.optional(dyn.string)),
    dyn.field("docs_html_url", dyn.optional(dyn.string)),
    dyn.field(
      "meta",
      dyn.decode3(
        PackageMeta,
        dyn.field("links", dyn.map(dyn.string, dyn.string)),
        dyn.field("licenses", dyn.list(dyn.string)),
        dyn.field("description", dyn.optional(dyn.string)),
      ),
    ),
    dyn.field("downloads", dyn.map(dyn.string, dyn.int)),
    dyn.any([
      dyn.field("owners", dyn.optional(dyn.list(decode_package_owner))),
      fn(_) { Ok(None) },
    ]),
    dyn.field(
      "releases",
      dyn.list(dyn.decode3(
        PackageRelease,
        dyn.field("version", dyn.string),
        dyn.field("url", dyn.string),
        dyn.field("inserted_at", decode_iso_timestamp),
      )),
    ),
    dyn.field("inserted_at", decode_iso_timestamp),
    dyn.field("updated_at", decode_iso_timestamp),
  )(data)
}

/// Information on a release from Hex's `/api/packages/:name/releases/:version`
/// endpoint.
pub type Release {
  Release(
    version: String,
    url: String,
    checksum: String,
    downloads: Int,
    publisher: Option(PackageOwner),
    meta: ReleaseMeta,
    retirement: Option(ReleaseRetirement),
    inserted_at: DateTime,
    updated_at: DateTime,
  )
}

/// Meta for a hex release
pub type ReleaseMeta {
  ReleaseMeta(app: Option(String), build_tools: List(String))
}

pub type ReleaseRetirement {
  ReleaseRetirement(reason: RetirementReason, message: Option(String))
}

pub type RetirementReason {
  OtherReason
  Invalid
  Security
  Deprecated
  Renamed
}

pub fn decode_retirement_reason(
  data: Dynamic,
) -> Result(RetirementReason, List(DecodeError)) {
  case dyn.string(data) {
    Error(e) -> Error(e)
    Ok("invalid") -> Ok(Invalid)
    Ok("security") -> Ok(Security)
    Ok("deprecated") -> Ok(Deprecated)
    Ok("renamed") -> Ok(Renamed)
    Ok(_) -> Ok(OtherReason)
  }
}

pub fn retirement_reason_to_string(reason: RetirementReason) -> String {
  case reason {
    OtherReason -> "other"
    Invalid -> "invalid"
    Security -> "security"
    Deprecated -> "deprecated"
    Renamed -> "renamed"
  }
}

pub fn decode_release(data: Dynamic) -> Result(Release, List(DecodeError)) {
  dyn.decode9(
    Release,
    dyn.field("version", dyn.string),
    dyn.field("url", dyn.string),
    dyn.field("checksum", dyn.string),
    dyn.field(
      "downloads",
      dyn.any([
        dyn.int,
        // For some unknown reason Hex will return [] when there are no downloads.
        function.constant(Ok(0)),
      ]),
    ),
    dyn.field("publisher", dyn.optional(decode_package_owner)),
    dyn.field(
      "meta",
      dyn.decode2(
        ReleaseMeta,
        dyn.field("app", dyn.optional(dyn.string)),
        dyn.field("build_tools", dyn.list(dyn.string)),
      ),
    ),
    dyn.field(
      "retirement",
      dyn.optional(dyn.decode2(
        ReleaseRetirement,
        dyn.field("reason", decode_retirement_reason),
        dyn.field("message", dyn.optional(dyn.string)),
      )),
    ),
    dyn.field("inserted_at", decode_iso_timestamp),
    dyn.field("updated_at", decode_iso_timestamp),
  )(data)
}

fn decode_package_owner(
  data: Dynamic,
) -> Result(PackageOwner, List(DecodeError)) {
  dyn.decode3(
    PackageOwner,
    dyn.field("username", dyn.string),
    dyn.any([
      dyn.field("email", dyn.optional(dyn.string)),
      function.constant(Ok(None)),
    ]),
    dyn.field("url", dyn.string),
  )(data)
}

fn decode_iso_timestamp(data: Dynamic) -> Result(DateTime, List(DecodeError)) {
  use s <- result.then(dyn.string(data))
  case time.from_iso8601(s) {
    Ok(t) -> Ok(t)
    Error(_) -> Error([DecodeError("Timestamp", dyn.classify(data), [])])
  }
}
