# script to plot footprint with observed XCO2 on spatial maps,
# written by Dien Wu, 06/18/2018

# add the sum of foot in plotted region, DW, 07/18/2018
# last update, DW, 08/22/2018

ggmap.xfoot.obs <- function(mm, lon.lat, site, oco2.path, facet.nrow, nhrs,
  dpar, foot.sf, zisf, met, stilt.ver, timestr, font.size = rel(0.9), recp.lon,
  recp.lat, foot, foot.sig, titleTF = T, sumTF = T, picname, storeTF = T,
  width = 12, height = 8){

  col <- def.col()
  m1 <- mm[[1]] + theme_bw() + coord_equal(1.1)

  # grab observations using map lat/lon
  map.ext <- data.frame(
    minlon = min(mm[[1]]$data$lon),
    maxlon = max(mm[[1]]$data$lon),
    minlat = min(mm[[1]]$data$lat),
    maxlat = max(mm[[1]]$data$lat))

  cat('Reading OCO-2 data according to the spatial domain of ggmap...\n')
  obs <- grab.oco2(ocopath = oco2.path, timestr = timestr, lon.lat = map.ext)

  # select footprints using map.ext
  library(dplyr)
  sel.foot <- foot %>% filter(
    lon >= map.ext$minlon & lon <= map.ext$maxlon &
    lat >= map.ext$minlat & lat <= map.ext$maxlat &
    foot >= foot.sig)

  title <- paste0('Spatial time-integrated weighted column footprint (',
    nhrs, ' hours; ', dpar, ' dpar; ', foot.sf, '; ziscale = ', zisf,
    '; met = ', met, ')\nusing STILT version', stilt.ver, ' for overpass on ',
    timestr, ' for ', site,
    '\nOnly large footprints > ', foot.sig,' are displayed')
  if (titleTF == F) title <- NULL

  p1 <- m1 + labs(title = title, x = 'LONGITUDE [E]', y = 'LATITUDE [N]')

  # if there is 1+ receptors
  if ('fac' %in% colnames(sel.foot)){
    if (length(unique(sel.foot$fac)) > 1){

      # summing the values within map domain
      sum.foot <- sel.foot %>% group_by(fac) %>% dplyr::summarize(sum = sum(foot))

      # receptor locations and add receptors on map
      sel.recp <- data.frame(lon = recp.lon, lat = recp.lat,
        fac = unique(sel.foot$fac)) %>% full_join(sum.foot, by = 'fac') %>%
        mutate(x = map.ext$maxlon - 0.8, y = map.ext$maxlat - 0.5)
      print(sel.recp)

      p1 <- p1 +
        geom_point(data = sel.recp, aes(lon, lat), colour = 'purple', size = 2) +
        facet_wrap(~ fac, nrow = facet.nrow) +
        geom_text(data = sel.recp, aes(lon + 0.4, lat),
          colour = 'purple', size = 4, label = 'receptor', fontface = 2) +
        facet_wrap(~ fac, nrow = facet.nrow)

      if (sumTF) p1 <- p1 + geom_text(data = sel.recp,
          aes(x, y, label = signif(sum, 3)), fontface = 2, size = 4)
    } # end if
  }  # end if

  # plot observed XCO2, add footprint raster layer
  p2 <- p1 +
    geom_point(data = obs[obs$qf == 0, ], aes(lon, lat, colour = xco2),
      size = 0.3) +
    geom_raster(data = sel.foot, aes(lon + mm[[3]], lat + mm[[2]], fill = foot),
      alpha = 0.8) +
    scale_fill_gradientn(limits = c(foot.sig, 1E-2), name = 'Xfoot',
      trans = 'log10', colours = col,
      breaks = sort(unique(c(foot.sig, 1E-6, 1E-4, 1E-2, 0.1, 1.0))),
      labels = sort(unique(c(foot.sig, 1E-6, 1E-4, 1E-2, 0.1, 1.0)))) +
    scale_alpha_manual(values = c('all' = 0.5, 'screened' = 1.0))

  if ('fac' %in% colnames(sel.foot)){
    if (length(unique(sel.foot$fac)) > 1)
      p2 <- p2 + facet_wrap(~ fac, nrow = facet.nrow) +
        theme(strip.text = element_text(size = font.size))
  }

  p3 <- p2 + theme(legend.position = 'bottom',
    legend.text = element_text(size = font.size),
    legend.key = element_blank(), legend.key.width = unit(width/8, 'cm'),
    legend.key.height = unit(height/20, 'cm'),
    axis.title.y = element_text(size = font.size, angle = 90),
    axis.title.x = element_text(size = font.size, angle = 0),
    axis.text = element_text(size = font.size),
    axis.ticks = element_line(size = font.size),
    title = element_text(size = font.size))

  max.y  <- ceiling(max(obs$xco2))
  min.y  <- floor(min(obs$xco2))
  breaks <- seq(min.y, max.y, 2)
  limits <- c(min.y, max.y)

  p4 <- p3 + scale_colour_gradientn(name = 'OBS XCO2:', colours = col,
    limits = limits, breaks = breaks, labels = breaks)
  p4 <- p4 + guides(colour = guide_colourbar(order = 2),
    fill = guide_legend(order = 1, nrow = 1))

  print(picname)
  if (storeTF) ggsave(p4, file = picname, width = width, height = height)

  return(p4)
}
