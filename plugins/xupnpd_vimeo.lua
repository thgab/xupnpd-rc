-- Copyright (C) 2011-2013 Anton Burdinuk
-- clark15b@gmail.com
-- https://tsdemuxer.googlecode.com/svn/trunk/xupnpd

cfg.vimeo_video_count=100

function vimeo_parse_feed(feed_url)
    local t={}

    local feed_data=http.download(feed_url)

    if feed_data then
        local x=json.decode(feed_data)

        feed_data=nil

        if x then
            local idx=1
            for i,j in ipairs(x) do
                t[idx]={ ['title']=j.title, ['link']=j.url, ['logo']=j.thumbnail_medium }
                idx=idx+1
            end
        end
    end

    return t
end

-- username, channel/channelname, group/groupname, album/album_id
function vimeo_updatefeed(feed,friendly_name)
    local rc=false

    local feed_url='http://vimeo.com/api/v2/'..feed..'/videos.json'
    local feed_name='vimeo_'..string.gsub(feed,'/','_')
    local feed_m3u_path=cfg.feeds_path..feed_name..'.m3u'
    local tmp_m3u_path=cfg.tmp_path..feed_name..'.m3u'

    local x=rss_merge(vimeo_parse_feed(feed_url),rss_parse_m3u(feed_m3u_path),cfg.vimeo_video_count)

--    local x=vimeo_parse_feed(feed_url)

    if x then
        local dfd=io.open(tmp_m3u_path,'w+')
        if dfd then
            dfd:write('#EXTM3U name=\"',friendly_name or feed_name,'\" type=mp4 plugin=vimeo\n')

            for i,j in ipairs(x) do
                if j.logo then
                    dfd:write('#EXTINF:0 logo=',j.logo,' ,',j.title,'\n',j.link,'\n')
                else
                    dfd:write('#EXTINF:0 ,',j.title,'\n',j.link,'\n')
                end
            end
            dfd:close()

            if util.md5(tmp_m3u_path)~=util.md5(feed_m3u_path) then
                if os.rename(tmp_m3u_path,feed_m3u_path) then
                    if cfg.debug>0 then print('Vimeo feed \''..feed_name..'\' updated') end
                    rc=true
                end
            else
                util.unlink(tmp_m3u_path)
            end
        end
    end

    return rc
end

-- send '\r\n' before data
function vimeo_sendurl(vimeo_url,range)

    if plugin_sendurl_from_cache(vimeo_url,range) then return end

    local url=vimeo_get_video_url(vimeo_url)

    if url==nil then
        if cfg.debug>0 then print('Vimeo clip '..vimeo_url..' is not found') end

        plugin_sendfile('www/corrupted.mp4')
    else
        if cfg.debug>0 then print('Vimeo Real URL: '..url) end

        plugin_sendurl(vimeo_url,url,range)
    end

end

function vimeo_get_video_url(vimeo_url)

    local url=nil

    local vimeo_id=string.match(vimeo_url,'.+/(%w+)$')

    local clip_page=plugin_download(vimeo_url)

    if clip_page then
        local ts,sig=string.match(clip_page,'"timestamp":(%w+),"signature":"(%w+)",')
        clip_page=nil

        if sig and ts then
            url=string.format('http://player.vimeo.com/play_redirect?clip_id=%s&sig=%s&time=%s&quality=hd&codecs=H264&type=moogaloop_local&embed_location=',vimeo_id,sig,ts)
        end
    end

    return url

end

plugins['vimeo']={}
plugins.vimeo.name="Vimeo"
plugins.vimeo.desc="<i>username</i>, channel/<i>channelname</i>, group/<i>groupname</i>, album/<i>album_id</i>"
plugins.vimeo.sendurl=vimeo_sendurl
plugins.vimeo.updatefeed=vimeo_updatefeed
plugins.vimeo.getvideourl=vimeo_get_video_url

plugins.vimeo.ui_config_vars=
{
    { "input",  "vimeo_video_count", "int" }
}
