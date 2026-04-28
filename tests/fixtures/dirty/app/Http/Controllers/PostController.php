<?php

namespace App\Http\Controllers;

use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PostController extends Controller
{
    public function index(Request $request)
    {
        $posts = Post::all();
        foreach ($posts as $post) {
            $post->author->name;
        }

        return $posts;
    }

    public function store(Request $request)
    {
        Log::info('Creating post: ' . $request->title);

        $sql = "SELECT * FROM users WHERE name = '" . $request->input('author') . "'";
        $author = DB::select($sql);

        return Post::create($request->all());
    }
}
