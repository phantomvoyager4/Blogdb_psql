DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Posts;
DROP TABLE IF EXISTS Comments;

CREATE TABLE Users (
    user_id serial primary key not null,
    email varchar(255) unique not null,
    username name not null,
    birthdate date,
    password varchar(255) not null
);

CREATE TABLE Posts (
    post_id serial primary key,
    user_id integer references Users(user_id),
    title text not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Comments (
    comment_id serial primary key,
    post_id integer references Posts(post_id),
    user_id integer references Users(user_id),
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);