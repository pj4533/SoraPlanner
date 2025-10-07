# OpenAI Video API



## Create Video

```
curl https://api.openai.com/v1/videos \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=sora-2" \
  -F "prompt=A calico cat playing a piano on stage"
```

```
{
  "id": "video_123",
  "object": "video",
  "model": "sora-2",
  "status": "queued",
  "progress": 0,
  "created_at": 1712697600,
  "size": "1024x1808",
  "seconds": "8",
  "quality": "standard"
}

```

### Request Body

prompt: string (required) - Text prompt that describes the video to generate.

seconds: string - Clip duration in seconds. Defaults to 4 seconds.



## List Videos

Returns a paginated list of [video jobs](https://platform.openai.com/docs/api-reference/videos/object) for the organization.

```
curl https://api.openai.com/v1/videos \
  -H "Authorization: Bearer $OPENAI_API_KEY"

```

```
{
  "data": [
    {
      "id": "video_123",
      "object": "video",
      "model": "sora-2",
      "status": "completed"
    }
  ],
  "object": "list"
}

```

## Retreive Video

Returns the [video job](https://platform.openai.com/docs/api-reference/videos/object) matching the provided identifier.

`GET https://api.openai.com/v1/videos/{video_id}`

## Delete Video

Delete a video - Returns the deleted video job metadata.

`DELETE https://api.openai.com/v1/videos/{video_id}`

## Retreive Video Content

Download video content - not sure the exact way they returns, but defaults to mp4

`GET https://api.openai.com/v1/videos/{video_id}/content`

## Video Job

Structured information describing a generated video job.

```
{
	completed_at: integer // Unix timestamp (seconds) for when the job completed, if finished.
	created_at: integer // Unix timestamp (seconds) for when the job was created.
	error { // Error payload that explains why generation failed, if applicable.
		code: string
		message: string
	}
	expires_at: integer // Unix timestamp (seconds) for when the downloadable assets expire, if set.
	id: string // Unique identifier for the video job.
	progress: integer // Approximate completion percentage for the generation task.
	model: string // The video generation model that produced the job.
	remixed_from_video_id: string // Identifier of the source video if this video is a remix.
	seconds: string // Duration of the generated clip in seconds.
	size: string // The resolution of the generated video.
	status: string // Current lifecycle status of the video job.
}
```

