
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_post.dart';
import '../services/social_post_service.dart';
import 'post_comments_screen.dart';

class SocialFeedScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  const SocialFeedScreen({super.key,this.onProfileTap});
  @override State<SocialFeedScreen> createState()=>_SocialFeedScreenState();
}
class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final _service=SocialPostService(), _composer=TextEditingController(), _picker=ImagePicker();
  final List<XFile> _images=[];
  List<SocialPost> _posts=[];
  bool _loading=true,_posting=false;
  @override void initState(){super.initState();_load();}
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;
  @override void dispose(){_composer.dispose();super.dispose();}

  Future<void> _load() async {
    if(mounted)setState(()=>_loading=true);
    try{final p=await _service.getFeed();if(mounted)setState(()=>_posts=p);}
    catch(e){if(mounted)_message('Could not load the campus feed: $e');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> _pickImages() async {
    try{
      final picked=await _picker.pickMultiImage(imageQuality:85,maxWidth:2000);
      if(picked.isEmpty)return;
      final remaining=5-_images.length;
      setState(()=>_images.addAll(picked.take(remaining)));
      if(picked.length>remaining)_message('You can attach up to 5 photos.');
    }catch(e){_message('Could not select photos: $e');}
  }
  Future<void> _create() async {
    if(_posting)return;
    if(_composer.text.trim().isEmpty&&_images.isEmpty){_message('Write something or add a photo first.');return;}
    setState(()=>_posting=true);
    try{
      final payload=<({String name,Uint8List bytes,String mime})>[];
      for(final f in _images){
        final ext=f.name.split('.').last.toLowerCase();
        payload.add((name:f.name,bytes:await f.readAsBytes(),mime:ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg'));
      }
      final urls=payload.isEmpty?<String>[]:await _service.uploadPostImages(payload);
      await _service.createPost(_composer.text,imageUrls:urls);
      _composer.clear();_images.clear();if(mounted)FocusScope.of(context).unfocus();
      await _load();
      if(mounted)_message('Your post is live on campus.');
    }catch(e){if(mounted)_message('Could not publish post: $e');}
    finally{if(mounted)setState(()=>_posting=false);}
  }
  Future<void> _deletePost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This post and its comments and likes will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePost(post.id);
      await _load();
      if (mounted) _message('Post deleted.');
    } catch (e) {
      if (mounted) _message('Could not delete post: $e');
    }
  }

  Future<void> _like(SocialPost post) async {
    try{await _service.toggleLike(post);await _load();}
    catch(e){if(mounted)_message('Could not update like: $e');}
  }
  String _ago(DateTime d){
    final x=DateTime.now().difference(d);
    if(x.inMinutes<1)return 'Just now';if(x.inHours<1)return '${x.inMinutes}m ago';
    if(x.inDays<1)return '${x.inHours}h ago';if(x.inDays<7)return '${x.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override Widget build(BuildContext context){
    final t=Theme.of(context);
    return SafeArea(child:RefreshIndicator(onRefresh:_load,child:CustomScrollView(physics:const AlwaysScrollableScrollPhysics(),slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(18,16,18,0),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('nook.',style:t.textTheme.displayLarge?.copyWith(color:t.colorScheme.primary,fontSize:32)),
            Text('A little place for your campus life.',style:t.textTheme.bodyMedium),
          ])),
          IconButton(tooltip:'Refresh feed',onPressed:_load,icon:const Icon(Icons.refresh_rounded)),
          InkWell(onTap:widget.onProfileTap,borderRadius:BorderRadius.circular(30),child:CircleAvatar(backgroundColor:t.colorScheme.primary.withValues(alpha:.16),child:Icon(Icons.person_outline,color:t.colorScheme.primary)))
        ]),
        const SizedBox(height:18),
        _composerCard(t),
        const SizedBox(height:24),
        Row(children:[Text('Campus feed',style:t.textTheme.titleLarge),const Spacer(),Text('${_posts.length} posts',style:t.textTheme.bodyMedium)]),
        const SizedBox(height:12),
      ]))),
      if(_loading)const SliverFillRemaining(hasScrollBody:false,child:Center(child:CircularProgressIndicator()))
      else if(_posts.isEmpty)SliverFillRemaining(hasScrollBody:false,child:Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.forum_outlined,size:54,color:t.colorScheme.primary),const SizedBox(height:14),
        Text('Your campus feed starts here',style:t.textTheme.titleLarge),
        const SizedBox(height:6),Text('Share an update, ask a question or post a campus moment.',textAlign:TextAlign.center,style:t.textTheme.bodyMedium),
      ]))))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(18,0,18,110),sliver:SliverList.separated(
        itemCount:_posts.length,separatorBuilder:(_,__)=>const SizedBox(height:13),
        itemBuilder:(context,i)=>_postCard(t,_posts[i]))),
    ])));
  }

  Widget _composerCard(ThemeData t)=>Container(
    padding:const EdgeInsets.all(15),
    decoration:BoxDecoration(color:t.colorScheme.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:t.dividerColor)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CircleAvatar(radius:20,backgroundColor:t.colorScheme.primary.withValues(alpha:.16),child:Icon(Icons.person_outline,color:t.colorScheme.primary)),
        const SizedBox(width:11),
        Expanded(child:TextField(
          controller:_composer,minLines:2,maxLines:5,maxLength:1000,
          textCapitalization:TextCapitalization.sentences,
          decoration:InputDecoration(
            hintText:"What's happening on campus?",counterText:'',
            filled:true,fillColor:t.colorScheme.surfaceContainerHighest,
            contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),
            focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:t.colorScheme.primary)),
          ),
        )),
      ]),
      if(_images.isNotEmpty)...[
        const SizedBox(height:12),
        SizedBox(height:82,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:_images.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i)=>FutureBuilder<Uint8List>(
          future:_images[i].readAsBytes(),builder:(context,s)=>Stack(children:[
            ClipRRect(borderRadius:BorderRadius.circular(12),child:s.hasData?Image.memory(s.data!,width:82,height:82,fit:BoxFit.cover):Container(width:82,height:82,color:t.colorScheme.surfaceContainerHighest)),
            Positioned(right:3,top:3,child:InkWell(onTap:()=>setState(()=>_images.removeAt(i)),child:Container(padding:const EdgeInsets.all(3),decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:14))))
          ])))),
      ],
      const SizedBox(height:12),Divider(height:1,color:t.dividerColor),const SizedBox(height:10),
      Row(children:[
        TextButton.icon(onPressed:_posting||_images.length>=5?null:_pickImages,icon:Icon(Icons.add_photo_alternate_outlined,color:t.colorScheme.primary),label:Text('Photo',style:TextStyle(color:t.colorScheme.primary))),
        Text('${_images.length}/5',style:t.textTheme.bodySmall),
        const Spacer(),
        FilledButton.icon(onPressed:_posting?null:_create,icon:_posting?const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send_rounded,size:16),label:Text(_posting?'Posting':'Post'),style:FilledButton.styleFrom(minimumSize:const Size(105,40),padding:const EdgeInsets.symmetric(horizontal:16))),
      ])
    ]),
  );

  Widget _postCard(ThemeData t,SocialPost p){
    final name=(p.authorName?.trim().isNotEmpty??false)?p.authorName!:'Nook student';
    return Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:t.colorScheme.surface,borderRadius:BorderRadius.circular(20),border:Border.all(color:t.dividerColor)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        CircleAvatar(radius:20,backgroundColor:t.colorScheme.primary.withValues(alpha:.16),child:Text(name[0].toUpperCase(),style:TextStyle(color:t.colorScheme.primary,fontWeight:FontWeight.w700))),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,style:t.textTheme.titleMedium),Text('${_ago(p.createdAt)}${p.groupName==null?'':'  ·  ${p.groupName}'}',style:t.textTheme.bodySmall),
        ])),
        if (p.userId == _userId)
          PopupMenuButton<String>(
            tooltip: 'Post options',
            onSelected: (value) {
              if (value == 'delete') _deletePost(p);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete post')),
            ],
            icon: const Icon(Icons.more_horiz),
          )
      ]),
      if(p.content.isNotEmpty)...[const SizedBox(height:12),SelectableText(p.content,style:t.textTheme.bodyLarge?.copyWith(height:1.5))],
      if(p.imageUrls.isNotEmpty)...[const SizedBox(height:12),_photoGrid(p.imageUrls)],
      const SizedBox(height:10),Divider(height:1,color:t.dividerColor),
      Row(children:[
        TextButton.icon(onPressed:()=>_like(p),icon:Icon(p.likedByMe?Icons.favorite:Icons.favorite_border,color:p.likedByMe?Colors.redAccent:t.colorScheme.onSurfaceVariant),label:Text('${p.likeCount}')),
        TextButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PostCommentsScreen(postId:p.id))).then((_)=>_load()),icon:const Icon(Icons.mode_comment_outlined),label:Text('${p.commentCount}')),
        const Spacer(),Icon(Icons.public_rounded,size:16,color:t.colorScheme.onSurfaceVariant),const SizedBox(width:5),Text('Campus',style:t.textTheme.bodySmall),
      ])
    ]));
  }

  Widget _photoGrid(List<String> urls){
    if(urls.length==1)return ClipRRect(borderRadius:BorderRadius.circular(15),child:Image.network(urls.first,width:double.infinity,height:230,fit:BoxFit.cover,errorBuilder:(_,__,___)=>_imageError()));
    return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:urls.length>4?4:urls.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:6,mainAxisSpacing:6),itemBuilder:(context,i)=>ClipRRect(borderRadius:BorderRadius.circular(12),child:Stack(fit:StackFit.expand,children:[
      Image.network(urls[i],fit:BoxFit.cover,errorBuilder:(_,__,___)=>_imageError()),
      if(i==3&&urls.length>4)Container(color:Colors.black54,child:Center(child:Text('+${urls.length-4}',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold))))
    ])));
  }
  Widget _imageError()=>Container(height:160,color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Center(child:Icon(Icons.broken_image_outlined)));
}
