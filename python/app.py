from flask import Flask, jsonify, request, send_from_directory
import boto3
from botocore.exceptions import ClientError
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app    = Flask(__name__)
REGION = os.environ.get("AWS_REGION", "us-east-1")

def s3():
    return boto3.client("s3", region_name=REGION)

# ── Frontend ──────────────────────────────────────────────────────
@app.route("/")
def index():
    return send_from_directory(os.path.join(BASE_DIR, "static"), "index.html")

# ── API: list all buckets ─────────────────────────────────────────
@app.route("/api/buckets")
def api_buckets():
    try:
        resp = s3().list_buckets()
        return jsonify({
            "region":  REGION,
            "buckets": [b["Name"] for b in resp.get("Buckets", [])]
        })
    except ClientError as e:
        return jsonify({"error": str(e)}), 500

# ── API: list objects at a prefix ─────────────────────────────────
@app.route("/api/objects")
def api_objects():
    bucket = request.args.get("bucket", "")
    prefix = request.args.get("prefix", "")

    if not bucket:
        return jsonify({"error": "bucket is required"}), 400

    try:
        resp = s3().list_objects_v2(
            Bucket=bucket,
            Prefix=prefix,
            Delimiter="/"
        )

        # CommonPrefixes = virtual folders (e.g. "images/")
        folders = [
            {
                "name": cp["Prefix"][len(prefix):].rstrip("/"),
                "path": cp["Prefix"],
                "type": "folder"
            }
            for cp in resp.get("CommonPrefixes", [])
        ]

        # Collect the folder paths so we can exclude them from files
        folder_paths = {cp["Prefix"] for cp in resp.get("CommonPrefixes", [])}

        files = [
            {
                "name": obj["Key"][len(prefix):],
                "path": obj["Key"],
                "type": "file",
                "size": obj["Size"],
                "date": obj["LastModified"].strftime("%Y-%m-%d %H:%M")
            }
            for obj in resp.get("Contents", [])
            # skip the prefix placeholder itself
            if obj["Key"] != prefix
            # skip 0-byte folder placeholder objects (keys ending with /)
            and not obj["Key"].endswith("/")
            # skip anything that is already listed as a folder
            and obj["Key"] not in folder_paths
        ]

        return jsonify({
            "bucket":    bucket,
            "prefix":    prefix,
            "folders":   folders,
            "files":     files,
            "truncated": resp.get("IsTruncated", False)
        })

    except ClientError as e:
        return jsonify({"error": str(e)}), 500

# ── API: generate presigned URL (1 hour) ─────────────────────────
@app.route("/api/presign")
def api_presign():
    bucket = request.args.get("bucket", "")
    key    = request.args.get("key", "")

    if not bucket or not key:
        return jsonify({"error": "bucket and key are required"}), 400

    try:
        url = s3().generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=3600
        )
        return jsonify({"url": url})
    except ClientError as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
