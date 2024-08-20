from ml.jobs.obj_detection.invoke.uri_folder import invoke as invoke_uri_folder


endpoint_name = "tennis-objs"
deployment_name = "tennis-objs"


def invoke(input_path: str) -> str:
    job_id = invoke_uri_folder(input_path, endpoint_name, deployment_name)
    return job_id

